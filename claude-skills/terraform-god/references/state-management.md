# State Management

## Table of Contents
- [State Philosophy](#state-philosophy)
- [Backend Configuration](#backend-configuration)
- [State Boundaries](#state-boundaries)
- [Workspaces vs Directories](#workspaces-vs-directories)
- [State Operations](#state-operations)
- [Remote State Data Sources](#remote-state-data-sources)
- [State Locking](#state-locking)
- [Disaster Recovery](#disaster-recovery)

## State Philosophy

**State is sacred**: The state file is the source of truth for what Terraform manages. Corrupt it, lose it, or let it drift, and you're in for pain.

**State should be remote**: Local state is acceptable only for learning. Production workloads require remote state with locking.

**State should be small**: Large state files slow everything down. If you have >100 resources in one state, consider splitting.

**State should match ownership**: The team that owns the resources should own the state. Cross-team dependencies should use remote state data sources.

## Backend Configuration

### AWS S3 Backend (Production Standard)
```hcl
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "prod/networking/terraform.tfstate"
    region         = "eu-west-2"

    # Locking via DynamoDB
    dynamodb_table = "terraform-locks"

    # Encryption at rest
    encrypt        = true

    # Optional: SSE-KMS
    kms_key_id     = "alias/terraform-state"

    # Optional: assume role for cross-account
    role_arn       = "arn:aws:iam::123456789012:role/TerraformStateAccess"
  }
}
```

### Azure Backend
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatestorage"
    container_name       = "tfstate"
    key                  = "prod/networking.tfstate"

    # Use Azure AD authentication
    use_azuread_auth     = true
  }
}
```

### GCP Backend
```hcl
terraform {
  backend "gcs" {
    bucket = "myorg-terraform-state"
    prefix = "prod/networking"
  }
}
```

### Terraform Cloud/Enterprise
```hcl
terraform {
  cloud {
    organization = "myorg"

    workspaces {
      name = "prod-networking"
    }
  }
}
```

### Partial Configuration (CI/CD Pattern)
```hcl
# backend.tf - partial config, completed at runtime
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    dynamodb_table = "terraform-locks"
    encrypt        = true
    region         = "eu-west-2"
    # key is provided at init time
  }
}
```

```bash
# CI/CD provides the key
terraform init -backend-config="key=prod/networking/terraform.tfstate"
```

## State Boundaries

### When to Split State

**Split by lifecycle**:
```
states/
├── foundation/          # VPC, IAM roles - rarely changes
│   └── terraform.tfstate
├── data/                # RDS, ElastiCache - changes occasionally
│   └── terraform.tfstate
└── application/         # ECS, Lambda - changes frequently
    └── terraform.tfstate
```

**Split by team ownership**:
```
states/
├── platform/            # Platform team owns
│   └── terraform.tfstate
├── team-a/              # Team A owns
│   └── terraform.tfstate
└── team-b/              # Team B owns
    └── terraform.tfstate
```

**Split by blast radius**:
- Networking changes affect everything → isolated state
- Database changes affect applications → separate from app state
- Application changes are localized → can be together

### State Key Naming Convention
```
{environment}/{component}/terraform.tfstate

Examples:
prod/networking/terraform.tfstate
prod/data/rds/terraform.tfstate
prod/apps/api-service/terraform.tfstate
staging/apps/api-service/terraform.tfstate
```

## Workspaces vs Directories

### Workspaces
Same code, different state files. Good for identical environments.

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch
terraform workspace select prod

# Use in code
locals {
  environment = terraform.workspace

  instance_counts = {
    dev     = 1
    staging = 2
    prod    = 3
  }

  instance_count = local.instance_counts[terraform.workspace]
}
```

**Workspace pros**:
- Single codebase
- Easy to keep environments in sync
- Simple for identical environments

**Workspace cons**:
- Can't have different provider versions per workspace
- Easy to run against wrong workspace
- All workspaces share same backend config

### Directory Structure
Different directories for different environments.

```
environments/
├── dev/
│   ├── main.tf
│   ├── backend.tf      # Points to dev state
│   └── terraform.tfvars
├── staging/
│   ├── main.tf
│   ├── backend.tf      # Points to staging state
│   └── terraform.tfvars
└── prod/
    ├── main.tf
    ├── backend.tf      # Points to prod state
    └── terraform.tfvars
```

**Directory pros**:
- Explicit environment context (can't accidentally apply to wrong env)
- Can have different provider versions per environment
- Can have different backend configurations
- Easier to audit changes per environment

**Directory cons**:
- Code duplication (mitigate with modules)
- Harder to keep environments in sync

### Recommendation
Use **directories** for production workloads. The safety of explicit environment context outweighs the convenience of workspaces.

## State Operations

### State Inspection
```bash
# List all resources
terraform state list

# Show specific resource
terraform state show 'aws_instance.web'

# Show full state (JSON)
terraform show -json | jq

# Pull remote state locally
terraform state pull > state-backup.json
```

### State Surgery

**Rename a resource** (after refactoring):
```bash
terraform state mv 'aws_instance.old_name' 'aws_instance.new_name'

# For modules
terraform state mv 'module.old_module.aws_instance.this' 'module.new_module.aws_instance.this'
```

**Remove from state** (resource now managed elsewhere or deleted manually):
```bash
terraform state rm 'aws_instance.orphan'

# Remove entire module
terraform state rm 'module.deprecated'
```

**Import existing resource**:
```bash
# Classic import
terraform import 'aws_instance.existing' 'i-1234567890abcdef0'

# Import into module
terraform import 'module.web.aws_instance.this' 'i-1234567890abcdef0'
```

**Terraform 1.5+ Import Blocks** (declarative):
```hcl
import {
  id = "i-1234567890abcdef0"
  to = aws_instance.web
}

# Generate config
terraform plan -generate-config-out=generated.tf
```

**Move Between States**:
```bash
# Pull source state
cd source-project
terraform state pull > source.tfstate

# Remove from source
terraform state rm 'aws_instance.moving'

# Add to destination
cd ../destination-project
terraform state mv -state=../source-project/source.tfstate -state-out=terraform.tfstate 'aws_instance.moving' 'aws_instance.moved'

# Or use terraform state push after manual edit
```

### Moved Blocks (Refactoring)
For refactoring without state surgery:

```hcl
# Tell Terraform about the rename
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}

moved {
  from = module.old_module
  to   = module.new_module
}

# Moving into a module
moved {
  from = aws_instance.web
  to   = module.web.aws_instance.this
}

# Moving between module instances
moved {
  from = module.web["old_key"]
  to   = module.web["new_key"]
}
```

## Remote State Data Sources

### Reading Another State
```hcl
# Read VPC state
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "myorg-terraform-state"
    key    = "prod/networking/terraform.tfstate"
    region = "eu-west-2"
  }
}

# Use outputs
resource "aws_instance" "web" {
  subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
}
```

### Alternative: Data Sources
When possible, prefer native data sources over remote state:

```hcl
# Instead of remote state for VPC
data "aws_vpc" "main" {
  tags = {
    Environment = "prod"
    Name        = "main-vpc"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Tier = "private"
  }
}
```

**Prefer data sources when**:
- You don't control the other state
- You only need a few attributes
- The resource has stable, queryable identifiers

**Prefer remote state when**:
- You need many outputs
- You need to ensure dependency ordering
- Both states are in the same project/team

## State Locking

### DynamoDB Lock Table (AWS)
```hcl
# One-time setup
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Purpose = "Terraform state locking"
  }
}
```

### Breaking a Stuck Lock
```bash
# Check who has the lock
aws dynamodb get-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "myorg-terraform-state/prod/networking/terraform.tfstate"}}'

# Force unlock (DANGEROUS - ensure no one else is running)
terraform force-unlock LOCK_ID
```

## Disaster Recovery

### State Backup Strategy

**S3 Versioning**:
```hcl
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

**Cross-Region Replication**:
```hcl
resource "aws_s3_bucket_replication_configuration" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "state-replication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.terraform_state_replica.arn
      storage_class = "STANDARD"
    }
  }
}
```

### State Recovery Procedures

**Recover from S3 version**:
```bash
# List versions
aws s3api list-object-versions \
  --bucket myorg-terraform-state \
  --prefix prod/networking/terraform.tfstate

# Restore specific version
aws s3api copy-object \
  --bucket myorg-terraform-state \
  --copy-source "myorg-terraform-state/prod/networking/terraform.tfstate?versionId=VERSION_ID" \
  --key prod/networking/terraform.tfstate
```

**Rebuild state from scratch**:
```bash
# List all resources in AWS (example)
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId'

# Import each resource
terraform import aws_instance.web i-1234567890abcdef0
terraform import aws_instance.app i-0987654321fedcba0

# Verify
terraform plan  # Should show no changes if successful
```

### State Corruption Recovery
1. Pull the corrupted state: `terraform state pull > corrupted.json`
2. Attempt to read it with `jq . corrupted.json`
3. If JSON is valid but Terraform rejects it, check:
   - Version compatibility
   - Resource schema changes
   - Provider version mismatches
4. If unrecoverable, restore from backup or rebuild via imports
