# GCP Patterns & Knowledge

## Table of Contents
- [Core Concepts](#core-concepts)
- [IAM & Security](#iam--security)
- [SDK Patterns (Go/Python)](#sdk-patterns)
- [Organisation Structure](#organisation-structure)
- [Common Services](#common-services)
- [Gotchas & Debugging](#gotchas--debugging)

## Core Concepts

### Resource Model
Hierarchical model with **fully-qualified resource names**:
```
//compute.googleapis.com/projects/my-project/zones/europe-west2-a/instances/my-vm
//storage.googleapis.com/projects/_/buckets/my-bucket
```

### Resource Hierarchy
```
Organisation
  └── Folder
        └── Project
              └── Resource
```

**Projects are the billing and API boundary** — most resources live in a project.

### Control Plane vs Data Plane
- **Control plane:** Resource management (create VM, configure bucket)
- **Data plane:** Content operations (read objects, query BigQuery)

Unlike Azure, no explicit `isDataAction` tag — control vs data plane distinction must be understood by the target service API.

### Regions & Zones
- **Region:** Geographic area (europe-west2 = London)
- **Zone:** Isolated location within region (europe-west2-a, -b, -c)
- **Multi-region / Dual-region:** For geo-redundant storage (`nam4`, `eu`, `us`)
- Some services are **global** (Cloud DNS, IAM)

## IAM & Security

### Principal Types
| Principal | Format | Use Case |
|-----------|--------|----------|
| User | `user:email@example.com` | Human access |
| Service Account | `serviceAccount:sa@project.iam.gserviceaccount.com` | Apps, automation |
| Service Agent | `serviceAccount:service-PROJECT_NUMBER@*.iam.gserviceaccount.com` | GCP system operations (e.g. GCS CMEK) |
| Group | `group:group@example.com` | Bulk assignment |
| Domain | `domain:example.com` | All users in domain |
| allUsers | `allUsers` | Anonymous (public) |
| allAuthenticatedUsers | `allAuthenticatedUsers` | Any Google account |

### IAM Policy Model & Evaluation
**Additive only** — GCP IAM has no explicit deny (use Organisation Policies for restrictions).

```json
{
  "bindings": [{
    "role": "roles/viewer",
    "members": ["user:alice@example.com", "serviceAccount:sa@project.iam.gserviceaccount.com"]
  }]
}
```

### Double-IAM Requirement for CMEK Encrypted Data
For a principal (or service account) to read or write a CMEK-encrypted GCS object, it must hold **BOTH**:
1. **Data-Plane Role:** `roles/storage.objectViewer` or `objectAdmin` on the bucket.
2. **KMS Crypto Role:** `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the KMS key.
*Gotcha:* If either is missing, GCS obscures the failure and returns a `404 Not Found` or generic `403 Access Denied` to prevent object enumeration.

### Service Accounts & Workload Identity Federation (WIF)
- **User-managed:** You create and control.
- **Service agents:** Auto-created by GCP services (e.g. `service-PROJECT_NUMBER@gs-project-accounts.iam.gserviceaccount.com`).
- **WIF Token Downscoping:** When federating external OIDC (AWS/Azure/Keycloak) via STS `generateAccessToken`, you **MUST** explicitly request the scope `https://www.googleapis.com/auth/cloud-platform`.
- **Cross-Project `actAs`:** To launch jobs in `Project B` using a Service Account in `Project B` from a Service Account in `Project A`, `sa-project-a` must hold `roles/iam.serviceAccountUser` specifically on `sa-project-b`.

## SDK Patterns

### Go SDK (google-cloud-go)

**Authentication:**
```go
import (
    "context"
    compute "cloud.google.com/go/compute/apiv1"
    "google.golang.org/api/option"
)

// Default credentials (ADC)
client, err := compute.NewInstancesRESTClient(context.Background())

// Impersonation with Cloud Platform Scope
client, err := compute.NewInstancesRESTClient(context.Background(),
    option.ImpersonateCredentials("target-sa@project.iam.gserviceaccount.com"),
    option.WithScopes("https://www.googleapis.com/auth/cloud-platform"),
)
```

### Python SDK (google-cloud-python)

**Resilient GCS CMEK Upload with KMS Retry Predicate:**
```python
from google.cloud import storage
from google.api_core import exceptions, retry

def _is_kms_retryable(exc: Exception) -> bool:
    if isinstance(exc, (exceptions.TooManyRequests, exceptions.ServiceUnavailable)):
        return True
    if isinstance(exc, exceptions.Forbidden) and "Cloud KMS CryptoKey" in str(exc):
        return True # Throttled KEK requests manifest as 403s
    return False

kms_upload_retry = retry.Retry(
    predicate=_is_kms_retryable,
    initial=0.5,
    maximum=10.0,
    multiplier=2.0,
    deadline=60.0
)

client = storage.Client()
bucket = client.bucket("my-cmek-bucket")
blob = bucket.blob("batch_01.parquet")
kms_upload_retry(blob.upload_from_filename)("local_file.parquet")
```

## Gotchas & Debugging

### Quotas & Misleading Error Messages (CRITICAL)

| Issue / Error | Real Cause | Remediation |
|-------|-------|-----|
| `403 Forbidden: service account does not have permission on Cloud KMS key...` | **KMS Quota Saturation:** High-concurrency writes (`>2,000 files/sec`) exhaust the KMS `crypto_requests` quota. GCS wraps quota failures in a `403`. | Request Cloud KMS quota increase in location (`nam4`/`global`) or implement exponential retry jitter. |
| `FAILED_PRECONDITION: Object gs://... does not exist` immediately after upload | **Dual-Region Replication Lag:** Multi-region or dual-region GCS buckets without Turbo replication experience sub-second cross-region RPO lag. | Enable `rpo = "ASYNC_TURBO"` on dual-region buckets or add explicit `blob.exists()` verification loop prior to downstream jobs. |
| `PERMISSION_DENIED` with correct role | **API Not Enabled:** API is disabled on the target project. | Enable API via `gcloud services enable <api>.googleapis.com`. |
| Cross-project `ActAs` denied | **Missing `serviceAccountUser`:** Impersonating SA lacks `roles/iam.serviceAccountUser` on target SA. | Grant `roles/iam.serviceAccountUser` on the target SA resource. |
