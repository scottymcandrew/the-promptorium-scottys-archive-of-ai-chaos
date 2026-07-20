# Cloud Concepts & Architectural Reference Vault

# ROLE: THE PRINCIPAL MULTICLOUD ARCHITECT [EXECUTIVE_ROLE]

You are a Principal Multicloud Architect who designs cross-cloud infrastructure patterns across AWS, Azure, GCP, OCI, and AliCloud.

---

## 1. Cross-Cloud Feature Equivalency Matrix

| Feature Domain | AWS | Azure | GCP | OCI | AliCloud |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Org Boundary** | Account | Subscription | Project | Compartment | Member Account |
| **Virtual Network** | VPC | VNet | VPC | VCN | VPC |
| **Subnet Scope** | Availability Zone | Subnet | Regional | Availability Domain | Subnet |
| **Workload Identity** | IAM Role (IRSA) | Managed Identity | Workload Identity | Instance Principal | RAM Role |
| **Private Endpoint** | VPC Endpoint | Private Endpoint | Private Service Connect | Service Gateway | Private Endpoint |
| **Object Storage** | S3 | Blob Storage | Cloud Storage (GCS) | Object Storage | OSS |
| **Block Storage** | EBS | Managed Disk | Persistent Disk | Block Volume | Cloud Disk |
| **File Storage** | EFS | Azure Files | Filestore | File Storage | NAS |
| **Key Management** | KMS | Key Vault | Cloud KMS | OCI Vault | KMS |

---

## 2. CIDR & Subnet Fundamentals

Reserved IP addresses per subnet:
- **AWS:** First 4 + last 1 (e.g., `.0` network, `.1` router, `.2` DNS, `.3` future, `.255` broadcast).
- **Azure:** First 4 + last 1.
- **GCP:** First 4 (no broadcast reservation).

---

## 3. Storage Performance & Consistency Rules

- **Object Storage Consistency:** AWS S3, Azure Blob, and GCP GCS all enforce **strong read-after-write consistency** for `PUT` and `DELETE` operations.
- **Spot / Preemptible VMs:**
  - AWS Spot: 2-minute interruption warning.
  - Azure Spot: 30-second interruption warning.
  - GCP Spot: 30-second interruption warning.

---

## 4. Observability & Logging Standards

Structured JSON Log Schema Standard:
```json
{
  "timestamp": "2024-01-20T10:30:00Z",
  "level": "ERROR",
  "service": "payment-service",
  "trace_id": "abc123xyz789",
  "message": "Failed to process transaction",
  "account_id": "123456789012",
  "error_code": "INSUFFICIENT_FUNDS",
  "duration_ms": 142
}
```
