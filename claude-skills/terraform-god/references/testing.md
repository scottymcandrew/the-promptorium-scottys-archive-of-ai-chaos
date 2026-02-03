# Testing Strategies

## Table of Contents
- [Testing Philosophy](#testing-philosophy)
- [Testing Pyramid](#testing-pyramid)
- [Static Analysis](#static-analysis)
- [Terraform Test Framework](#terraform-test-framework)
- [Terratest](#terratest)
- [Policy as Code](#policy-as-code)
- [Integration Testing](#integration-testing)

## Testing Philosophy

**Test infrastructure like code**: Infrastructure bugs are expensive. A failed deployment is worse than a failed unit test.

**Shift left**: Catch problems early. Static analysis catches more than you think.

**Test reality, not mocks**: Integration tests against real providers catch real issues. Mocks give false confidence.

**Policy as code is testing**: Sentinel, OPA, and tfsec are tests. Treat them that way.

## Testing Pyramid

```
            /\
           /  \
          / E2E \        <- Full stack tests (expensive, slow)
         /--------\
        /Integration\    <- Real provider tests
       /--------------\
      / Contract Tests \  <- Module interface tests
     /------------------\
    /   Policy/Static    \ <- Fast, cheap, catches most issues
   /______________________\
```

**Bottom of pyramid**: Run on every commit
- `terraform fmt`
- `terraform validate`
- tfsec, checkov, tflint
- OPA policies

**Middle**: Run on PR
- Terraform test (native)
- Terratest (unit mode)

**Top**: Run before merge to main
- Integration tests with real resources
- End-to-end tests

## Static Analysis

### terraform fmt
```bash
# Check formatting
terraform fmt -check -recursive

# Fix formatting
terraform fmt -recursive
```

### terraform validate
```bash
# Syntax and reference validation
terraform init -backend=false
terraform validate
```

### tflint
```bash
# Install
brew install tflint

# Run with AWS plugin
tflint --init
tflint --recursive

# Configuration (.tflint.hcl)
```

```hcl
# .tflint.hcl
plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
```

### tfsec / Trivy
```bash
# Install tfsec
brew install tfsec

# Scan
tfsec .

# Ignore specific checks
tfsec . --exclude aws-s3-enable-bucket-logging

# Output formats
tfsec . --format=json > results.json
```

```hcl
# Inline ignore
resource "aws_s3_bucket" "example" {
  #tfsec:ignore:aws-s3-enable-bucket-logging
  bucket = "my-bucket"
}
```

### checkov
```bash
# Install
pip install checkov

# Scan
checkov -d .

# Skip checks
checkov -d . --skip-check CKV_AWS_18,CKV_AWS_21
```

### Pre-commit Hooks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.86.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_tfsec
      - id: terraform_docs

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
```

```bash
# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

## Terraform Test Framework

Native testing framework (Terraform 1.6+).

### Test Structure
```
module/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── basic.tftest.hcl
    └── advanced.tftest.hcl
```

### Basic Test
```hcl
# tests/basic.tftest.hcl

# Variables for tests
variables {
  name        = "test-bucket"
  environment = "test"
}

# Test that creates real resources
run "create_bucket" {
  command = apply

  assert {
    condition     = aws_s3_bucket.this.bucket == "test-bucket"
    error_message = "Bucket name doesn't match"
  }

  assert {
    condition     = aws_s3_bucket.this.tags["Environment"] == "test"
    error_message = "Environment tag not set correctly"
  }
}

# Plan-only test (no resources created)
run "plan_only" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket != ""
    error_message = "Bucket name should not be empty"
  }
}
```

### Mock Providers
```hcl
# tests/mock.tftest.hcl

mock_provider "aws" {
  alias = "mock"
}

run "with_mock" {
  providers = {
    aws = aws.mock
  }

  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == var.name
    error_message = "Bucket name mismatch"
  }
}
```

### Testing Modules
```hcl
# tests/module.tftest.hcl

run "test_vpc_module" {
  module {
    source = "./modules/vpc"
  }

  variables {
    cidr_block = "10.0.0.0/16"
    name       = "test-vpc"
  }

  assert {
    condition     = module.vpc.vpc_id != ""
    error_message = "VPC ID should not be empty"
  }
}
```

### Running Tests
```bash
# Run all tests
terraform test

# Run specific test file
terraform test -filter=basic.tftest.hcl

# Verbose output
terraform test -verbose

# With variables
terraform test -var="environment=test"
```

## Terratest

Go-based testing framework for infrastructure.

### Basic Test
```go
// test/vpc_test.go
package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVpc(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/vpc",
        Vars: map[string]interface{}{
            "cidr_block": "10.0.0.0/16",
            "name":       "test-vpc",
        },
    }

    // Clean up after test
    defer terraform.Destroy(t, terraformOptions)

    // Deploy
    terraform.InitAndApply(t, terraformOptions)

    // Validate outputs
    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)
}
```

### AWS Integration Test
```go
package test

import (
    "testing"

    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/service/ec2"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestS3Bucket(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/s3",
        Vars: map[string]interface{}{
            "bucket_name": "test-bucket-" + random.UniqueId(),
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    bucketArn := terraform.Output(t, terraformOptions, "arn")

    // Verify with AWS SDK
    sess := session.Must(session.NewSession())
    s3Client := s3.New(sess)

    _, err := s3Client.HeadBucket(&s3.HeadBucketInput{
        Bucket: aws.String(terraform.Output(t, terraformOptions, "bucket_name")),
    })
    assert.NoError(t, err)
}
```

### Running Terratest
```bash
# Run tests
cd test
go test -v -timeout 30m

# Run specific test
go test -v -timeout 30m -run TestVpc

# With parallelism
go test -v -timeout 30m -parallel 4
```

## Policy as Code

### Open Policy Agent (OPA)
```rego
# policy/terraform.rego
package terraform

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not resource.change.after.server_side_encryption_configuration
    msg := sprintf("S3 bucket '%s' must have encryption enabled", [resource.address])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group_rule"
    resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
    resource.change.after.type == "ingress"
    msg := sprintf("Security group rule '%s' allows ingress from 0.0.0.0/0", [resource.address])
}
```

```bash
# Generate plan JSON
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json

# Evaluate with OPA
opa eval --data policy/ --input tfplan.json "data.terraform.deny"

# Fail if any denies
opa eval --data policy/ --input tfplan.json --fail-defined "data.terraform.deny[x]"
```

### Sentinel (Terraform Enterprise)
```hcl
# policies/s3-encryption.sentinel
import "tfplan/v2" as tfplan

s3_buckets = filter tfplan.resource_changes as _, rc {
    rc.type is "aws_s3_bucket" and
    rc.mode is "managed" and
    (rc.change.actions contains "create" or rc.change.actions contains "update")
}

deny_unencrypted_buckets = rule {
    all s3_buckets as _, bucket {
        bucket.change.after.server_side_encryption_configuration is not null
    }
}

main = rule {
    deny_unencrypted_buckets
}
```

### Conftest
```bash
# Install
brew install conftest

# Test with Rego policies
terraform plan -out=tfplan
terraform show -json tfplan | conftest test -

# With custom policy
conftest test tfplan.json --policy policy/
```

## Integration Testing

### Test Environments
```hcl
# environments/test/main.tf
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "test/terraform.tfstate"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name       = "test-vpc-${random_id.suffix.hex}"
  cidr_block = "10.99.0.0/16"

  tags = {
    Environment = "test"
    Purpose     = "integration-testing"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}
```

### CI/CD Integration Test Pipeline
```yaml
# .github/workflows/test.yml
name: Integration Tests

on:
  pull_request:
    paths:
      - 'modules/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_TEST_ROLE }}
          aws-region: eu-west-2

      - name: Run Terraform Tests
        run: terraform test -verbose
        working-directory: modules/vpc

      - name: Cleanup
        if: always()
        run: terraform destroy -auto-approve
        working-directory: environments/test
```

### Ephemeral Test Infrastructure
```hcl
# Use random suffixes for isolation
resource "random_id" "test" {
  byte_length = 4
}

locals {
  test_prefix = "test-${random_id.test.hex}"
}

resource "aws_s3_bucket" "test" {
  bucket = "${local.test_prefix}-bucket"

  tags = {
    Purpose   = "integration-test"
    Ephemeral = "true"
  }
}
```

### Cleanup Automation
```bash
#!/bin/bash
# cleanup-test-resources.sh

# Find resources older than 24 hours
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Purpose,Values=integration-test \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output text | while read arn; do
    # Get creation time and delete if old
    # Implementation depends on resource type
    echo "Would delete: $arn"
done
```
