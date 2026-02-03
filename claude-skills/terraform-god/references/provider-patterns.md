# Provider Patterns

## Table of Contents
- [Provider Philosophy](#provider-philosophy)
- [Authentication Patterns](#authentication-patterns)
- [Multi-Region/Multi-Account](#multi-regionmulti-account)
- [Version Management](#version-management)
- [Provider Debugging](#provider-debugging)
- [Common Providers Reference](#common-providers-reference)

## Provider Philosophy

**Providers are the bridge**: They translate your HCL into API calls. Understanding your provider is as important as understanding Terraform itself.

**Authentication should be external**: Never hardcode credentials. Use environment variables, IAM roles, or OIDC.

**Version lock aggressively**: Provider updates can break things. Use pessimistic version constraints.

## Authentication Patterns

### AWS Authentication

**Recommended: OIDC (for CI/CD)**
```hcl
# No credentials in Terraform - GitHub Actions assumes role
provider "aws" {
  region = "eu-west-2"

  assume_role_with_web_identity {
    role_arn                = "arn:aws:iam::123456789012:role/GitHubActionsRole"
    session_name            = "terraform-${var.environment}"
    web_identity_token_file = "/var/run/secrets/eks.amazonaws.com/serviceaccount/token"
  }
}
```

**Assume Role (Cross-Account)**
```hcl
provider "aws" {
  region = "eu-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::123456789012:role/TerraformDeployRole"
    session_name = "terraform-deploy"
    external_id  = var.external_id  # For third-party access
  }
}
```

**Environment Variables (Local Development)**
```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="eu-west-2"

# Or use AWS CLI profile
export AWS_PROFILE="dev-account"
```

**Shared Credentials File**
```hcl
provider "aws" {
  region                   = "eu-west-2"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "dev-account"
}
```

### Azure Authentication

**Recommended: OIDC (for CI/CD)**
```hcl
provider "azurerm" {
  features {}

  use_oidc        = true
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id  # App registration
}
```

**Service Principal**
```hcl
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret  # From env var
}
```

**Azure CLI (Local Development)**
```hcl
provider "azurerm" {
  features {}

  # Uses logged-in az cli context
  subscription_id = "12345678-1234-1234-1234-123456789012"
}
```

```bash
az login
az account set --subscription "12345678-1234-1234-1234-123456789012"
```

### GCP Authentication

**Recommended: Workload Identity (for GKE/CI)**
```hcl
provider "google" {
  project = var.project_id
  region  = var.region
  # Workload identity provides credentials automatically
}
```

**Service Account Key**
```hcl
provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.credentials_file)  # Path to JSON key
}
```

**Application Default Credentials (Local)**
```bash
gcloud auth application-default login
```

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
  # Uses ADC automatically
}
```

## Multi-Region/Multi-Account

### Provider Aliases
```hcl
# Default provider
provider "aws" {
  region = "eu-west-2"
}

# Additional regions
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "ap_southeast_1"
  region = "ap-southeast-1"
}

# Use in resources
resource "aws_s3_bucket" "london" {
  bucket = "my-bucket-london"
  # Uses default provider
}

resource "aws_s3_bucket" "virginia" {
  provider = aws.us_east_1
  bucket   = "my-bucket-virginia"
}
```

### Multi-Account with Assume Role
```hcl
provider "aws" {
  alias  = "dev"
  region = "eu-west-2"

  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/TerraformRole"
  }
}

provider "aws" {
  alias  = "prod"
  region = "eu-west-2"

  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/TerraformRole"
  }
}

# Resources in different accounts
resource "aws_s3_bucket" "dev" {
  provider = aws.dev
  bucket   = "dev-bucket"
}

resource "aws_s3_bucket" "prod" {
  provider = aws.prod
  bucket   = "prod-bucket"
}
```

### Passing Providers to Modules
```hcl
# Root module
provider "aws" {
  alias  = "london"
  region = "eu-west-2"
}

provider "aws" {
  alias  = "dublin"
  region = "eu-west-1"
}

module "primary" {
  source = "./modules/vpc"

  providers = {
    aws = aws.london
  }
}

module "secondary" {
  source = "./modules/vpc"

  providers = {
    aws = aws.dublin
  }
}

# In module - declare required providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Module uses the passed provider automatically
resource "aws_vpc" "this" {
  cidr_block = var.cidr
}
```

### Dynamic Provider Configuration
```hcl
locals {
  regions = ["eu-west-1", "eu-west-2", "us-east-1"]
}

# This doesn't work - can't use for_each with providers
# Instead, define each provider explicitly or use workspaces

# Alternative: separate root modules per region
# Or: use a wrapper script to generate providers
```

## Version Management

### Version Constraint Syntax
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # >= 5.0.0, < 6.0.0
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0, < 4.0.0"
    }

    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

### Lock File Management
```bash
# Generate/update lock file
terraform init -upgrade

# Lock file should be committed
git add .terraform.lock.hcl
git commit -m "Update provider versions"
```

**Lock file structure**:
```hcl
# .terraform.lock.hcl
provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.31.0"
  constraints = "~> 5.0"
  hashes = [
    "h1:abcd1234...",
    "zh:1234abcd...",
  ]
}
```

### Upgrading Providers Safely
1. Check changelog for breaking changes
2. Run `terraform init -upgrade` in non-prod first
3. Run `terraform plan` and review changes
4. Test in lower environments
5. Commit updated lock file
6. Apply to production

## Provider Debugging

### Enable Debug Logging
```bash
# All Terraform logs
TF_LOG=DEBUG terraform plan 2>&1 | tee debug.log

# Provider-specific (less noise)
TF_LOG_PROVIDER=DEBUG terraform plan 2>&1 | tee provider-debug.log

# Log levels: TRACE, DEBUG, INFO, WARN, ERROR
```

### Common Provider Issues

**Authentication Failures**:
```bash
# AWS - verify credentials
aws sts get-caller-identity

# Azure - verify context
az account show

# GCP - verify auth
gcloud auth list
gcloud config get-value project
```

**Rate Limiting**:
```hcl
# AWS - add retries
provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = var.common_tags
  }

  # Retry configuration
  retry_mode  = "standard"
  max_retries = 5
}
```

**API Permissions**:
```bash
# AWS - check what actions are denied
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/TerraformRole \
  --action-names s3:CreateBucket ec2:RunInstances
```

### Provider-Specific Environment Variables
```bash
# AWS
export AWS_DEFAULT_REGION="eu-west-2"
export AWS_MAX_ATTEMPTS="10"
export AWS_RETRY_MODE="adaptive"

# Azure
export ARM_SUBSCRIPTION_ID="..."
export ARM_TENANT_ID="..."
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."

# GCP
export GOOGLE_PROJECT="my-project"
export GOOGLE_REGION="europe-west2"
export GOOGLE_CREDENTIALS="/path/to/key.json"
```

## Common Providers Reference

### AWS Provider
```hcl
provider "aws" {
  region = "eu-west-2"

  # Default tags for all resources
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }

  # Ignore specific tags (managed externally)
  ignore_tags {
    key_prefixes = ["kubernetes.io/", "aws:"]
  }
}
```

### Azure Provider
```hcl
provider "azurerm" {
  features {
    # Soft delete settings
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }

  subscription_id = var.subscription_id
}
```

### GCP Provider
```hcl
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # Batching for quota management
  batching {
    enable_batching = true
    send_after      = "10s"
  }

  # User project for shared VPC
  user_project_override = true
}

# Beta features
provider "google-beta" {
  project = var.project_id
  region  = var.region
}
```

### Kubernetes Provider
```hcl
# From EKS
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# From kubeconfig
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "my-context"
}
```

### Helm Provider
```hcl
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }

  # Helm-specific settings
  experiments {
    manifest = true  # Enable manifest experiment
  }
}
```
