# Security Patterns

## Table of Contents
- [Security Philosophy](#security-philosophy)
- [Authentication & OIDC](#authentication--oidc)
- [Secrets Management](#secrets-management)
- [Least Privilege IAM](#least-privilege-iam)
- [State Security](#state-security)
- [Policy as Code](#policy-as-code)
- [Supply Chain Security](#supply-chain-security)

## Security Philosophy

**Credentials don't belong in code**: Ever. Not encrypted, not obfuscated, not "just for testing."

**Least privilege by default**: Start with nothing, add only what's needed.

**Immutable audit trails**: Log everything, encrypt at rest, alert on anomalies.

**Trust nothing, verify everything**: Validate inputs, check outputs, assume breach.

## Authentication & OIDC

### Why OIDC Over Static Credentials
- No secrets to rotate
- No secrets to leak
- Scoped to specific repos/branches
- Automatic token refresh
- Audit trail built-in

### AWS OIDC Setup
```hcl
# Create OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Role with trust policy
resource "aws_iam_role" "terraform" {
  name = "TerraformGitHubActions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Scope to specific repo and branches
          "token.actions.githubusercontent.com:sub" = [
            "repo:myorg/infrastructure:ref:refs/heads/main",
            "repo:myorg/infrastructure:pull_request"
          ]
        }
      }
    }]
  })
}
```

### Azure OIDC Setup
```hcl
# Federated identity credential
resource "azuread_application" "terraform" {
  display_name = "Terraform-GitHub-Actions"
}

resource "azuread_application_federated_identity_credential" "github" {
  application_object_id = azuread_application.terraform.object_id
  display_name          = "github-main"
  description           = "GitHub Actions main branch"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:myorg/infrastructure:ref:refs/heads/main"
}

resource "azuread_service_principal" "terraform" {
  application_id = azuread_application.terraform.application_id
}

# Assign role
resource "azurerm_role_assignment" "terraform" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.terraform.object_id
}
```

### GCP Workload Identity
```hcl
# Workload identity pool
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service account binding
resource "google_service_account_iam_member" "github" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/myorg/infrastructure"
}
```

## Secrets Management

### Using AWS Secrets Manager
```hcl
# Read secret
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
  # ...
}
```

### Using HashiCorp Vault
```hcl
provider "vault" {
  address = "https://vault.example.com"
  # Auth via VAULT_TOKEN env var or auth method
}

data "vault_generic_secret" "db" {
  path = "secret/prod/database"
}

resource "aws_db_instance" "main" {
  password = data.vault_generic_secret.db.data["password"]
  # ...
}
```

### Generating Secrets in Terraform
```hcl
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store in secrets manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "prod/database/password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

# Mark output as sensitive
output "db_password_secret_arn" {
  value     = aws_secretsmanager_secret.db_password.arn
  sensitive = false  # ARN is safe to show
}
```

### Never Do This
```hcl
# BAD - credentials in code
variable "db_password" {
  default = "supersecret123"  # NEVER
}

# BAD - credentials in tfvars
# terraform.tfvars
# db_password = "supersecret123"  # NEVER - this gets committed

# BAD - using environment variable without caution
# TF_VAR_db_password=secret  # Appears in process list
```

## Least Privilege IAM

### Generating Minimal Policies
```bash
# Use iamlive to capture required permissions
iamlive --mode proxy --output-file policy.json

# In another terminal
HTTPS_PROXY=http://127.0.0.1:10080 terraform apply
```

### AWS Permission Boundaries
```hcl
# Prevent privilege escalation
resource "aws_iam_policy" "boundary" {
  name = "TerraformPermissionBoundary"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = "*"
      },
      {
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateRole",
          "iam:AttachUserPolicy",
          "iam:AttachRolePolicy",
          "iam:PutUserPolicy",
          "iam:PutRolePolicy"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "iam:PermissionsBoundary" = "arn:aws:iam::123456789012:policy/TerraformPermissionBoundary"
          }
        }
      }
    ]
  })
}
```

### Scoped Terraform Role
```hcl
resource "aws_iam_role" "terraform" {
  name = "TerraformExecution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::123456789012:root"
      }
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.external_id
        }
      }
    }]
  })

  permissions_boundary = aws_iam_policy.boundary.arn
}

# Only permissions actually needed
resource "aws_iam_role_policy" "terraform" {
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "rds:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["eu-west-2"]
          }
        }
      }
    ]
  })
}
```

## State Security

### Encryption at Rest
```hcl
# S3 backend with KMS
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
    dynamodb_table = "terraform-locks"
  }
}

# KMS key for state
resource "aws_kms_key" "terraform_state" {
  description             = "Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTerraformRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.terraform.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### State Access Logging
```hcl
resource "aws_s3_bucket_logging" "state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "terraform-state-logs/"
}
```

### Sensitive Data in State
```hcl
# Mark sensitive outputs
output "database_password" {
  value     = random_password.db.result
  sensitive = true
}

# Resources with sensitive attributes
resource "aws_db_instance" "main" {
  # password is automatically marked sensitive in state
  password = data.aws_secretsmanager_secret_version.db.secret_string
}
```

## Policy as Code

### tfsec Rules
```yaml
# .tfsec.yaml
severity_overrides:
  aws-s3-enable-bucket-logging: ERROR
  aws-ec2-enforce-http-token-imds: ERROR

exclude:
  - aws-s3-enable-versioning  # We handle this separately
```

### OPA/Conftest Policies
```rego
# policy/security.rego
package terraform.security

# Deny public S3 buckets
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    resource.change.after.block_public_acls != true
    msg := sprintf("S3 bucket '%s' must block public ACLs", [resource.address])
}

# Require encryption
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_ebs_volume"
    resource.change.after.encrypted != true
    msg := sprintf("EBS volume '%s' must be encrypted", [resource.address])
}

# Require HTTPS
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lb_listener"
    resource.change.after.protocol == "HTTP"
    resource.change.after.port == 80
    not resource.change.after.default_action[_].redirect
    msg := sprintf("Load balancer listener '%s' must use HTTPS or redirect", [resource.address])
}
```

### Sentinel (Terraform Enterprise)
```hcl
# policies/require-tags.sentinel
import "tfplan/v2" as tfplan

required_tags = ["Environment", "Owner", "CostCenter"]

all_resources = filter tfplan.resource_changes as _, rc {
    rc.mode is "managed" and
    rc.change.actions contains "create"
}

taggable_resources = filter all_resources as _, resource {
    resource.change.after.tags is not null
}

main = rule {
    all taggable_resources as _, resource {
        all required_tags as tag {
            resource.change.after.tags contains tag
        }
    }
}
```

## Supply Chain Security

### Provider Verification
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"  # Official source
      version = "~> 5.0"
    }
  }
}
```

### Lock File Integrity
```bash
# Commit lock file
git add .terraform.lock.hcl
git commit -m "Update provider lock file"

# Verify in CI
terraform init -lockfile=readonly  # Fail if lock doesn't match
```

### Module Verification
```hcl
# Pin to specific version/commit
module "vpc" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=v5.0.0"
}

# Or use registry with version
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"  # Exact version
}
```

### Dependency Scanning
```yaml
# GitHub Actions - scan for vulnerabilities
- name: Scan dependencies
  uses: snyk/actions/iac@master
  with:
    file: .
```

### Private Registry
```hcl
# Use internal registry for modules
terraform {
  required_providers {
    internal = {
      source  = "registry.internal.example.com/myorg/internal"
      version = "~> 1.0"
    }
  }
}

module "vpc" {
  source  = "app.terraform.io/myorg/vpc/aws"
  version = "1.0.0"
}
```
