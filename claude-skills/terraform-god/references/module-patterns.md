# Module Design Patterns

## Table of Contents
- [Module Philosophy](#module-philosophy)
- [Module Types](#module-types)
- [Structure Conventions](#structure-conventions)
- [Composition Patterns](#composition-patterns)
- [Versioning Strategy](#versioning-strategy)
- [Input/Output Design](#inputoutput-design)
- [Anti-Patterns](#anti-patterns)

## Module Philosophy

**The Single Responsibility Principle applies to modules**: A module should do one thing well. If you're passing 50 variables, your module is doing too much.

**Modules are APIs**: Your variables are the request, your outputs are the response. Design them like you'd design a REST API—consistent, predictable, documented.

**Composition over configuration**: Build small, focused modules that compose together rather than one mega-module with a hundred feature flags.

## Module Types

### 1. Resource Modules (Building Blocks)
Thin wrappers around single resources or tightly coupled resource groups.

```hcl
# modules/s3-bucket/main.tf
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Use when**: You want reusable, opinionated defaults for a single resource type.

### 2. Composition Modules (Patterns)
Combine multiple resource modules into a common pattern.

```hcl
# modules/web-app/main.tf
module "alb" {
  source = "../alb"
  # ...
}

module "ecs_service" {
  source = "../ecs-service"
  target_group_arn = module.alb.target_group_arn
  # ...
}

module "rds" {
  source = "../rds"
  security_group_ids = [module.ecs_service.security_group_id]
  # ...
}
```

**Use when**: You have a recurring architectural pattern (e.g., "web app with database").

### 3. Root Modules (Deployments)
The actual deployments—these call composition modules with environment-specific values.

```hcl
# environments/prod/main.tf
module "web_app" {
  source = "../../modules/web-app"

  environment    = "prod"
  instance_count = 3
  instance_type  = "t3.large"
  # ...
}
```

**Use when**: Deploying actual infrastructure to a specific environment.

### 4. Wrapper Modules (Facades)
Simplify complex modules from public registries with organizational defaults.

```hcl
# modules/vpc-wrapper/main.tf
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  # Org defaults
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required from caller
  name       = var.name
  cidr       = var.cidr
  azs        = var.azs

  # Org standard subnet sizing
  private_subnets = [for i, az in var.azs : cidrsubnet(var.cidr, 4, i)]
  public_subnets  = [for i, az in var.azs : cidrsubnet(var.cidr, 4, i + 8)]

  tags = merge(var.tags, {
    ManagedBy = "terraform"
    Module    = "vpc-wrapper"
  })
}
```

## Structure Conventions

### Standard Module Layout
```
modules/
└── my-module/
    ├── main.tf           # Primary resources
    ├── variables.tf      # Input variables (alphabetized)
    ├── outputs.tf        # Output values
    ├── versions.tf       # Terraform and provider constraints
    ├── locals.tf         # Computed values (optional)
    ├── data.tf           # Data sources (optional)
    ├── README.md         # Usage documentation
    └── examples/         # Example usage
        └── basic/
            └── main.tf
```

### File Organization Rules

**versions.tf** — Always first, always present:
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**variables.tf** — Alphabetized, with descriptions:
```hcl
variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "name" {
  description = "Resource name prefix"
  type        = string
}
```

**outputs.tf** — Document what consumers need:
```hcl
output "arn" {
  description = "The ARN of the created resource"
  value       = aws_s3_bucket.this.arn
}

output "id" {
  description = "The ID of the created resource"
  value       = aws_s3_bucket.this.id
}
```

## Composition Patterns

### Pattern 1: Module Chaining
```hcl
module "network" {
  source = "./modules/network"
}

module "database" {
  source = "./modules/database"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
}

module "application" {
  source = "./modules/application"

  vpc_id              = module.network.vpc_id
  database_endpoint   = module.database.endpoint
  database_secret_arn = module.database.secret_arn
}
```

### Pattern 2: Module Factory (for_each)
```hcl
locals {
  environments = {
    dev  = { instance_type = "t3.small", count = 1 }
    prod = { instance_type = "t3.large", count = 3 }
  }
}

module "app" {
  source   = "./modules/application"
  for_each = local.environments

  environment   = each.key
  instance_type = each.value.instance_type
  instance_count = each.value.count
}
```

### Pattern 3: Optional Sub-modules
```hcl
module "monitoring" {
  source = "./modules/monitoring"
  count  = var.enable_monitoring ? 1 : 0

  resource_ids = module.application.instance_ids
}
```

## Versioning Strategy

### Semantic Versioning
```
v1.0.0  # Initial release
v1.1.0  # New features (backwards compatible)
v1.1.1  # Bug fixes
v2.0.0  # Breaking changes
```

### Module Source Patterns
```hcl
# Git with tag (recommended for private modules)
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=v1.2.3"
}

# Git with branch (for development only)
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=feature-branch"
}

# Terraform Registry
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}

# Local (for development)
module "vpc" {
  source = "../modules/vpc"
}
```

### Version Pinning Rules
- **Production**: Always pin exact versions or use pessimistic constraints (`~>`)
- **Development**: Can use branches, but never deploy to prod without version tag
- **CI/CD**: Lock file must be committed (`.terraform.lock.hcl`)

## Input/Output Design

### Variable Design Principles

**Required vs Optional**:
```hcl
# Required - no default
variable "name" {
  description = "Resource name (required)"
  type        = string
}

# Optional - sensible default
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```

**Complex Types**:
```hcl
variable "ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string, "Managed by Terraform")
  }))
  default = []
}
```

**Validation**:
```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "cidr_block" {
  type = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}
```

### Output Design Principles

**Output everything consumers might need**:
```hcl
output "id" {
  description = "Resource ID"
  value       = aws_instance.this.id
}

output "arn" {
  description = "Resource ARN"
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.this.private_ip
}

# For modules with for_each
output "instances" {
  description = "Map of instance details"
  value = {
    for k, v in aws_instance.this : k => {
      id         = v.id
      private_ip = v.private_ip
    }
  }
}
```

**Sensitive outputs**:
```hcl
output "database_password" {
  description = "Generated database password"
  value       = random_password.db.result
  sensitive   = true
}
```

## Anti-Patterns

### 1. The Mega-Module
```hcl
# BAD: One module tries to do everything
module "infrastructure" {
  source = "./modules/everything"

  # 50+ variables
  enable_vpc         = true
  enable_eks         = true
  enable_rds         = true
  enable_elasticache = true
  # ...
}
```

**Fix**: Break into focused modules that compose together.

### 2. Pass-Through Variables
```hcl
# BAD: Variable exists only to pass to child module
variable "vpc_cidr" {}
variable "vpc_name" {}
variable "vpc_tags" {}

module "vpc" {
  source = "./vpc"
  cidr   = var.vpc_cidr
  name   = var.vpc_name
  tags   = var.vpc_tags
}
```

**Fix**: Use a single object variable or restructure the module hierarchy.

### 3. Hardcoded Magic Values
```hcl
# BAD
resource "aws_instance" "web" {
  ami           = "ami-12345678"  # What is this?
  instance_type = "t3.large"      # Why this size?
}
```

**Fix**: Use variables with descriptive names and defaults with comments.

### 4. Missing Outputs
```hcl
# BAD: No outputs, consumers can't reference anything
resource "aws_vpc" "main" {
  cidr_block = var.cidr
}
# ... no outputs.tf
```

**Fix**: Always output id, arn, and any attribute consumers might need.

### 5. Provider Configuration in Modules
```hcl
# BAD: Provider config inside module
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  # ...
}
```

**Fix**: Never configure providers in reusable modules. Pass them from root.
