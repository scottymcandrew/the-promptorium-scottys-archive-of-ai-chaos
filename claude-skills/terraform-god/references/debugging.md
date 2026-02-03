# Debugging & Troubleshooting

## Table of Contents
- [Debugging Philosophy](#debugging-philosophy)
- [Error Categories](#error-categories)
- [Debug Logging](#debug-logging)
- [State Issues](#state-issues)
- [Dependency Issues](#dependency-issues)
- [Provider Issues](#provider-issues)
- [Common Errors Reference](#common-errors-reference)

## Debugging Philosophy

**Errors are information**: Every error tells you something. Read the whole message, not just the first line.

**Reproduce first**: Before fixing, ensure you can reproduce. Random fixes for non-reproducible issues create new problems.

**Isolate systematically**: Use binary search. Comment out half, see if it fails. Narrow down.

**State and providers cause 80% of issues**: When in doubt, check the state file and provider authentication.

## Error Categories

### 1. Configuration Errors
Caught at `terraform validate` or early in `terraform plan`.

**Symptoms**:
- Syntax errors
- Type mismatches
- Missing required arguments
- Invalid references

**Approach**:
```bash
terraform validate
terraform fmt -check
```

### 2. Provider Errors
Failed API calls during plan or apply.

**Symptoms**:
- Authentication failures
- Permission denied
- Resource not found
- Rate limiting

**Approach**:
```bash
TF_LOG_PROVIDER=DEBUG terraform plan 2>&1 | tee provider-debug.log
```

### 3. State Errors
State doesn't match reality or is corrupted.

**Symptoms**:
- Resource already exists
- Resource not found (but it's there)
- Unexpected changes on every plan
- State lock issues

**Approach**:
```bash
terraform state list
terraform state show 'resource.name'
terraform refresh
```

### 4. Dependency Errors
Resources can't be created/destroyed in the right order.

**Symptoms**:
- Cycle detected
- Resource depends on resource that will be destroyed
- Apply fails partway through

**Approach**:
```bash
terraform graph | dot -Tsvg > graph.svg
```

## Debug Logging

### Log Levels
```bash
# Maximum verbosity
TF_LOG=TRACE terraform plan

# Standard debug
TF_LOG=DEBUG terraform plan

# Provider-specific (less noise)
TF_LOG_PROVIDER=DEBUG terraform plan

# Core only (no provider logs)
TF_LOG_CORE=DEBUG terraform plan
```

### Structured Logging
```bash
# JSON output for parsing
TF_LOG=JSON terraform plan 2>&1 | jq 'select(.msg | contains("error"))'
```

### Log to File
```bash
TF_LOG=DEBUG TF_LOG_PATH=terraform.log terraform plan
```

### What to Look For in Logs

**Authentication issues**:
```
"@level":"debug","@message":"setting computed for \"id\" from ComputedKeys"
"@level":"error","@message":"Error: error configuring S3 backend: no valid credential sources"
```

**API errors**:
```
"@level":"debug","@message":"[aws-sdk-go] DEBUG: Response..."
"@level":"error","@message":"Error: error creating EC2 Instance: UnauthorizedOperation"
```

**State issues**:
```
"@level":"debug","@message":"Resource instance state: ObjectReady"
"@level":"warn","@message":"Resource instance out of sync"
```

## State Issues

### Resource Exists but Terraform Wants to Create
**Cause**: Resource was created outside Terraform or state was lost.

**Solution**:
```bash
# Import the existing resource
terraform import 'aws_instance.web' 'i-1234567890abcdef0'

# Verify no changes needed
terraform plan
```

### Resource Doesn't Exist but Terraform Shows It
**Cause**: Resource was deleted outside Terraform.

**Solution**:
```bash
# Option 1: Remove from state
terraform state rm 'aws_instance.deleted'

# Option 2: Refresh state
terraform refresh

# Option 3: Let Terraform recreate it
terraform apply
```

### Unexpected Changes on Every Plan
**Cause**: External modifications, provider bugs, or unstable attributes.

**Solution**:
```hcl
# Ignore external changes
lifecycle {
  ignore_changes = [tags, metadata]
}
```

Or investigate why changes are happening:
```bash
# Compare state with reality
terraform state show 'aws_instance.web'
aws ec2 describe-instances --instance-ids i-1234567890abcdef0
```

### State Lock Issues
**Cause**: Previous run crashed, concurrent runs, or orphaned lock.

**Solution**:
```bash
# Check who has the lock (AWS example)
aws dynamodb get-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "bucket/path/terraform.tfstate"}}'

# Wait for the lock to release OR
# Force unlock (DANGEROUS - only if you're CERTAIN no one else is running)
terraform force-unlock LOCK_ID
```

### State Corruption
**Symptoms**: JSON parse errors, schema validation failures.

**Solution**:
```bash
# Try to read the state
terraform state pull | jq .

# If it fails, restore from backup
aws s3api list-object-versions --bucket my-state-bucket --prefix path/terraform.tfstate
aws s3api get-object --bucket my-state-bucket --key path/terraform.tfstate --version-id VERSION_ID recovered.tfstate

# Push recovered state
terraform state push recovered.tfstate
```

## Dependency Issues

### Cycle Detected
**Error**: `Error: Cycle: resource_a -> resource_b -> resource_a`

**Debug**:
```bash
terraform graph | dot -Tsvg > graph.svg
# Open graph.svg to visualize the cycle
```

**Solutions**:
```hcl
# 1. Break implicit dependency with explicit reference
resource "aws_security_group" "a" {
  name = "sg-a"
  # Don't reference sg_b here
}

resource "aws_security_group" "b" {
  name = "sg-b"
  # Reference sg_a here if needed
}

# 2. Use separate rules instead of inline
resource "aws_security_group_rule" "a_to_b" {
  security_group_id        = aws_security_group.a.id
  source_security_group_id = aws_security_group.b.id
  # ...
}

# 3. Use depends_on to make order explicit
resource "aws_security_group" "b" {
  depends_on = [aws_security_group.a]
  # ...
}
```

### Destroy-Time Dependencies
**Error**: Can't destroy resource because something depends on it.

**Solution**:
```hcl
# Create new before destroying old
lifecycle {
  create_before_destroy = true
}
```

Or use targeted destroy:
```bash
terraform destroy -target='aws_instance.dependency'
terraform destroy -target='aws_instance.main'
```

### Graph Visualization
```bash
# Full graph
terraform graph | dot -Tsvg > full-graph.svg

# Plan graph (what will change)
terraform graph -type=plan | dot -Tsvg > plan-graph.svg

# Destroy graph
terraform graph -type=plan-destroy | dot -Tsvg > destroy-graph.svg
```

## Provider Issues

### Authentication Debugging
```bash
# AWS
aws sts get-caller-identity
TF_LOG_PROVIDER=DEBUG terraform plan 2>&1 | grep -i "auth\|credential\|assume"

# Azure
az account show
az account get-access-token

# GCP
gcloud auth list
gcloud config list
```

### Permission Errors
**AWS**:
```bash
# Find what action was denied
grep -i "UnauthorizedOperation\|AccessDenied" terraform.log

# Test specific action
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/TerraformRole \
  --action-names ec2:RunInstances
```

**Azure**:
```bash
# Check role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

### Rate Limiting
**Symptoms**: Intermittent failures, "RequestLimitExceeded", "Throttling".

**Solutions**:
```hcl
# Reduce parallelism
terraform apply -parallelism=5

# AWS provider retries
provider "aws" {
  retry_mode  = "adaptive"
  max_retries = 10
}
```

```bash
# Spread requests over time with targeted applies
terraform apply -target='module.batch1'
sleep 60
terraform apply -target='module.batch2'
```

### Provider Version Issues
**Symptoms**: Unknown attribute, changed behavior after upgrade.

**Debug**:
```bash
# Check installed versions
terraform version

# Check what's in lock file
cat .terraform.lock.hcl | grep -A2 "provider"

# Force specific version
terraform init -upgrade

# Downgrade if needed
# Change versions.tf, then:
rm -rf .terraform
terraform init
```

## Common Errors Reference

### "Error: Cycle detected"
See [Dependency Issues](#dependency-issues).

### "Error: Resource already exists"
```bash
# Resource exists in cloud but not in state
terraform import 'aws_s3_bucket.example' 'my-bucket-name'
```

### "Error: Provider produced inconsistent final plan"
**Cause**: Provider bug or race condition.

**Solutions**:
```bash
# Retry
terraform apply

# Target specific resource
terraform apply -target='problematic.resource'

# Check for provider updates
terraform init -upgrade
```

### "Error: Invalid count/for_each argument"
**Cause**: Value isn't known until apply.

**Solutions**:
```hcl
# Bad - depends on resource that doesn't exist yet
resource "aws_instance" "web" {
  count = length(aws_subnet.private.*.id)  # Unknown at plan time
}

# Good - use data source or variable
variable "instance_count" {
  default = 3
}

resource "aws_instance" "web" {
  count = var.instance_count
}
```

### "Error: Error acquiring state lock"
```bash
# Check who has it
# AWS:
aws dynamodb get-item --table-name terraform-locks \
  --key '{"LockID": {"S": "bucket/key"}}'

# Force unlock (if safe)
terraform force-unlock LOCK_ID
```

### "Error: Unsupported attribute"
**Cause**: Using attribute that doesn't exist or wrong resource type.

**Debug**:
```bash
# Check resource documentation
# Verify resource type
terraform state show 'resource.name'

# Check provider version supports the attribute
terraform version
```

### "Error: Reference to undeclared resource"
**Cause**: Typo in resource name or resource doesn't exist.

```bash
# List all resources
terraform state list

# Check for typos
grep -r "resource_name" *.tf
```

### "Error: Provider configuration not present"
**Cause**: Module requires provider that isn't configured.

```hcl
# Ensure provider is passed to module
module "example" {
  source = "./module"

  providers = {
    aws = aws.alias_name
  }
}
```
