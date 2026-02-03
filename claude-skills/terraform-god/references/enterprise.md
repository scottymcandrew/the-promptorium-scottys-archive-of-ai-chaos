# Enterprise & Scale Patterns

## Table of Contents
- [Enterprise Philosophy](#enterprise-philosophy)
- [Multi-Account Strategies](#multi-account-strategies)
- [Multi-Region Patterns](#multi-region-patterns)
- [Repository Structures](#repository-structures)
- [Team Workflows](#team-workflows)
- [Governance](#governance)
- [Migration Strategies](#migration-strategies)

## Enterprise Philosophy

**Scale is a people problem**: Technology enables scale, but org structure determines success.

**Blast radius over convenience**: A change that can break everything shouldn't be easy to make.

**Self-service with guardrails**: Enable teams to move fast within safe boundaries.

**Everything is auditable**: If you can't prove what changed, when, and by whom, you're not enterprise-ready.

## Multi-Account Strategies

### AWS Landing Zone Pattern
```
Organization
├── Management Account (billing, org policies)
├── Security OU
│   ├── Log Archive Account
│   └── Security Tooling Account
├── Infrastructure OU
│   ├── Network Account (Transit Gateway, shared VPCs)
│   └── Shared Services Account
└── Workload OUs
    ├── Development OU
    │   ├── Team-A Dev Account
    │   └── Team-B Dev Account
    ├── Staging OU
    │   └── Shared Staging Account
    └── Production OU
        ├── Team-A Prod Account
        └── Team-B Prod Account
```

### Account Vending Machine
```hcl
# modules/account/main.tf
resource "aws_organizations_account" "this" {
  name      = var.account_name
  email     = var.account_email
  parent_id = var.organizational_unit_id

  iam_user_access_to_billing = "DENY"

  tags = {
    Environment = var.environment
    Team        = var.team
    CostCenter  = var.cost_center
  }
}

# Baseline resources in new account
module "account_baseline" {
  source = "./modules/account-baseline"

  providers = {
    aws = aws.new_account
  }

  account_id = aws_organizations_account.this.id
  # ...
}
```

### Cross-Account Role Assumption
```hcl
# In each workload account
resource "aws_iam_role" "terraform" {
  name = "TerraformExecution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.management_account_id}:root"
      }
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.external_id
        }
      }
    }]
  })
}

# From management account
provider "aws" {
  alias  = "team_a_prod"
  region = "eu-west-2"

  assume_role {
    role_arn    = "arn:aws:iam::111111111111:role/TerraformExecution"
    external_id = var.external_id
  }
}
```

## Multi-Region Patterns

### Active-Active
```hcl
locals {
  regions = ["eu-west-2", "us-east-1"]
}

provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "regional_stack" {
  source = "./modules/regional-stack"

  for_each = toset(local.regions)

  providers = {
    aws = each.value == "eu-west-2" ? aws.eu_west_2 : aws.us_east_1
  }

  region      = each.value
  environment = var.environment
}

# Global resources (Route53, IAM)
module "global" {
  source = "./modules/global"

  providers = {
    aws = aws.us_east_1  # Global services in us-east-1
  }

  regional_endpoints = {
    for region, stack in module.regional_stack : region => stack.lb_dns_name
  }
}
```

### Active-Passive (DR)
```hcl
module "primary" {
  source = "./modules/full-stack"

  providers = {
    aws = aws.eu_west_2
  }

  is_primary = true
}

module "dr" {
  source = "./modules/full-stack"

  providers = {
    aws = aws.eu_west_1
  }

  is_primary = false

  # Reduced capacity in DR
  instance_count = var.dr_instance_count
  rds_replica_of = module.primary.rds_arn
}
```

### Global Accelerator / CloudFront
```hcl
resource "aws_globalaccelerator_accelerator" "main" {
  name            = "global-app"
  ip_address_type = "IPV4"
  enabled         = true
}

resource "aws_globalaccelerator_listener" "main" {
  accelerator_arn = aws_globalaccelerator_accelerator.main.id
  protocol        = "TCP"

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_globalaccelerator_endpoint_group" "eu" {
  listener_arn = aws_globalaccelerator_listener.main.id
  endpoint_group_region = "eu-west-2"

  endpoint_configuration {
    endpoint_id = module.regional_stack["eu-west-2"].lb_arn
    weight      = 100
  }

  health_check_path = "/health"
}
```

## Repository Structures

### Monorepo (Recommended for Most)
```
infrastructure/
├── modules/                    # Reusable modules
│   ├── vpc/
│   ├── eks/
│   ├── rds/
│   └── ...
├── environments/               # Deployments
│   ├── shared/                 # Shared infrastructure
│   │   └── networking/
│   ├── dev/
│   │   ├── team-a/
│   │   └── team-b/
│   ├── staging/
│   └── prod/
│       ├── eu-west-2/
│       └── us-east-1/
├── policies/                   # OPA/Sentinel policies
└── .github/                    # CI/CD
```

**Pros**: Single source of truth, easy cross-module changes, unified CI/CD
**Cons**: Everyone needs access, large diffs, contention

### Multi-Repo (For Large Orgs)
```
# Shared modules repo
terraform-modules/
├── vpc/
├── eks/
└── rds/

# Per-team/environment repos
team-a-infrastructure/
├── dev/
├── staging/
└── prod/

team-b-infrastructure/
└── ...
```

**Pros**: Team autonomy, isolated blast radius, separate permissions
**Cons**: Module versioning complexity, harder to coordinate

### Hybrid (Modules Shared, Deployments Separate)
```
# Shared modules (versioned, published)
terraform-modules/  # -> Published to private registry

# Per-team deployments
team-a-infrastructure/
├── modules.tf      # References terraform-modules v1.2.3
└── ...
```

## Team Workflows

### Platform Team Model
```
Platform Team                    Application Teams
     │                                │
     ├── Owns: VPC, EKS, RDS         ├── Owns: App-specific resources
     ├── Publishes: Modules          ├── Consumes: Platform modules
     └── Runs: Shared infra          └── Runs: App deployments
```

```hcl
# Platform team publishes
module "eks_cluster" {
  source  = "app.terraform.io/myorg/eks-cluster/aws"
  version = "2.0.0"

  # Platform-approved configuration
  cluster_version = "1.28"
  node_groups     = var.node_groups
}

# App team consumes
module "my_app" {
  source = "./modules/app"

  cluster_endpoint = data.terraform_remote_state.platform.outputs.eks_endpoint
  cluster_ca       = data.terraform_remote_state.platform.outputs.eks_ca
}
```

### GitOps with Atlantis
```yaml
# atlantis.yaml
version: 3
projects:
  - name: platform-networking
    dir: environments/shared/networking
    workflow: platform-workflow
    apply_requirements:
      - approved
      - mergeable

  - name: team-a-prod
    dir: environments/prod/team-a
    workflow: team-workflow
    apply_requirements:
      - approved

workflows:
  platform-workflow:
    plan:
      steps:
        - init
        - plan:
            extra_args: ["-lock=false"]
    apply:
      steps:
        - apply

  team-workflow:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply
```

## Governance

### Tagging Standards
```hcl
# Required tags enforced by policy
locals {
  required_tags = {
    Environment = var.environment
    Team        = var.team
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Repository  = var.repository
  }
}

# Apply to all resources via provider default_tags
provider "aws" {
  default_tags {
    tags = local.required_tags
  }
}
```

### Cost Allocation
```hcl
# Budget alerts per team
resource "aws_budgets_budget" "team" {
  for_each = var.teams

  name         = "team-${each.key}-monthly"
  budget_type  = "COST"
  limit_amount = each.value.monthly_budget
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Team$${each.key}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = each.value.budget_alerts_emails
  }
}
```

### Compliance Enforcement
```rego
# policy/compliance.rego
package terraform.compliance

# Enforce encryption everywhere
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not has_encryption(resource)
    msg := sprintf("S3 bucket '%s' must have encryption enabled", [resource.address])
}

# Enforce private subnets for databases
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.after.publicly_accessible == true
    msg := sprintf("RDS instance '%s' must not be publicly accessible", [resource.address])
}

# Enforce approved regions
approved_regions := ["eu-west-2", "eu-west-1"]

deny[msg] {
    resource := input.configuration.provider_config.aws[_]
    region := resource.expressions.region.constant_value
    not region in approved_regions
    msg := sprintf("Region '%s' is not approved. Use: %v", [region, approved_regions])
}
```

## Migration Strategies

### Migrating Existing Resources
```hcl
# 1. Write Terraform for existing resources
resource "aws_instance" "legacy" {
  ami           = "ami-12345678"
  instance_type = "t3.large"
  # ... match existing config
}

# 2. Import
import {
  id = "i-1234567890abcdef0"
  to = aws_instance.legacy
}

# 3. Generate config from import
terraform plan -generate-config-out=generated.tf
```

### Migrating Between States
```bash
# Source: old monolithic state
# Destination: new split states

# 1. Pull source state
terraform state pull > old-state.json

# 2. Move resources to new state
terraform state mv \
  -state=old-state.json \
  -state-out=new-networking.tfstate \
  'module.vpc' 'module.vpc'

# 3. Push new state
cd networking/
terraform state push new-networking.tfstate

# 4. Verify
terraform plan  # Should show no changes
```

### Migrating Modules
```hcl
# When upgrading module versions with breaking changes

# 1. Use moved blocks for renamed resources
moved {
  from = module.old_vpc.aws_vpc.main
  to   = module.new_vpc.aws_vpc.this
}

# 2. Import new resources
import {
  id = "vpc-12345678"
  to = module.new_vpc.aws_vpc.this
}

# 3. Remove deprecated resources from state
# (after apply succeeds)
terraform state rm 'module.old_vpc'
```

### Terraform Version Upgrades
```bash
# 1. Check upgrade notes
open https://developer.hashicorp.com/terraform/language/upgrade-guides

# 2. Upgrade in lower environments first
terraform version  # Current: 1.5.0 -> Target: 1.6.0

# 3. Run upgrade command if available
terraform 0.13upgrade  # Example for 0.12->0.13

# 4. Plan and verify
terraform init -upgrade
terraform plan

# 5. Apply and test
terraform apply

# 6. Commit updated lock file
git add .terraform.lock.hcl
git commit -m "Upgrade Terraform to 1.6.0"
```
