# Azure Patterns & Knowledge

## Table of Contents
- [Core Concepts](#core-concepts)
- [Identity & RBAC](#identity--rbac)
- [SDK Patterns (Go/Python)](#sdk-patterns)
- [Management Groups & Subscriptions](#management-groups--subscriptions)
- [Gotchas & Debugging](#gotchas--debugging)

## Core Concepts

### Control Plane vs Data Plane (`isDataAction`)
In Azure, naming conventions do **NOT** determine whether an action is control-plane or data-plane. **`isDataAction` is the definitive indicator.**

- **Control plane:** ARM operations (create VM, configure storage account) managed via `Microsoft.Authorization`.
- **Data plane:** Content operations (read blob, query Cosmos DB, Key Vault secrets).

```bash
# Query exact data plane status of an action
az provider operation show --namespace Microsoft.Storage \
  --resource-type blobServices/containers/blobs \
  --query "[].{Name:name, IsDataAction:isDataAction}"
```

## Identity & RBAC

### Deny Assignments & Inheritance
- **Deny Assignments Override Allow:** Even if a user is an `Owner` or `Contributor`, a Deny Assignment (e.g. applied by Azure Blueprints or Managed Applications) will strictly block access.
- **Querying Deny Assignments:**
```bash
az rest --method GET \
  --uri "/subscriptions/{sub_id}/providers/Microsoft.Authorization/denyAssignments?api-version=2022-04-01"
```

## Rate Limits & Throttling (CRITICAL)

### Graph API Multi-Tenant Throttling
For multi-tenant SaaS applications, Microsoft Graph API limits are **global per-application ID**, NOT per-customer subscription.
- **Limit:** ~10,000 requests / 10 minutes across ALL customer tenants combined.
- **Handling:** Always parse `Retry-After` response headers and implement token bucket backoff.
