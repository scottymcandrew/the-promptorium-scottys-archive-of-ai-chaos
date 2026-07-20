# Infrastructure as Code (IaC) Design Patterns

## Universal IaC Principles Across Cloud Providers

1. **State Lock & Encryption:** State files store plain-text secrets and connection strings. State backends MUST enforce server-side encryption (KMS/GCS CMEK) and state locking (DynamoDB / Blob lease).
2. **Provider Version Pinning:** Always pin provider minor versions to prevent breaking changes in CI/CD pipelines.
3. **Immutability & Refactoring Safety:** Use `moved` blocks (Terraform 1.1+) or `import` blocks (Terraform 1.5+) when renaming resources to prevent destructive recreation.

## Terraform Production Backend Blueprint
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

## Anti-Pattern Blacklist
- **NEVER** hardcode access keys, passwords, or tokens in `.tf` or `.yaml` files.
- **NEVER** run `terraform apply` in automated pipelines without explicit state locking enabled.
- **NEVER** use `count` when resource elements depend on dynamic lists that change order; use `for_each` with a stable map key.
