# Performance Optimization

## Table of Contents
- [Performance Philosophy](#performance-philosophy)
- [Profiling Terraform](#profiling-terraform)
- [State Optimization](#state-optimization)
- [Parallelism Tuning](#parallelism-tuning)
- [Targeted Operations](#targeted-operations)
- [Refresh Strategies](#refresh-strategies)
- [Large-Scale Patterns](#large-scale-patterns)

## Performance Philosophy

**Measure before optimizing**: Don't guess. Profile first, optimize what matters.

**State size is the biggest lever**: Large state files slow everything down. Split them.

**Parallelism has diminishing returns**: More parallel operations hit API limits faster.

**The fastest operation is the one you don't do**: Target operations, skip refreshes when safe.

## Profiling Terraform

### Timing Operations
```bash
# Basic timing
time terraform plan

# Detailed timing with logs
TF_LOG=INFO time terraform plan 2>&1 | tee plan.log

# Profile specific phases
time terraform plan -refresh-only      # Just refresh
time terraform plan -refresh=false     # Skip refresh
```

### What to Measure

| Metric | Command | Target |
|--------|---------|--------|
| Plan time | `time terraform plan` | < 60s for most configs |
| Apply time | `time terraform apply` | Varies by resources |
| State size | `wc -c terraform.tfstate` | < 10MB per state |
| Resource count | `terraform state list \| wc -l` | < 100 per state |
| Provider count | `grep "provider\[" .terraform.lock.hcl` | Minimize |

### Identifying Bottlenecks
```bash
# See what's taking time
TF_LOG=DEBUG terraform plan 2>&1 | grep -E "^\d{4}" | head -100

# Count resources by type
terraform state list | cut -d'.' -f1 | sort | uniq -c | sort -rn

# Find large resources in state
terraform state pull | jq '[.resources[].instances[].attributes | length] | add'
```

## State Optimization

### State Size Guidelines
| State Size | Resources | Action |
|------------|-----------|--------|
| < 1MB | < 50 | Fine as is |
| 1-10MB | 50-200 | Consider splitting |
| > 10MB | > 200 | Must split |

### Splitting Strategies

**By Lifecycle**:
```
states/
├── foundation/     # VPCs, IAM - rarely changes
├── data/           # Databases - occasional changes
└── application/    # Apps - frequent changes
```

**By Team**:
```
states/
├── platform-team/
├── app-team-a/
└── app-team-b/
```

**By Component**:
```
states/
├── networking/
├── compute/
├── storage/
└── monitoring/
```

### State Migration
```bash
# Move resources to new state
terraform state mv -state=old.tfstate -state-out=new.tfstate \
  'module.networking' 'module.networking'

# Or use backend reconfiguration
terraform init -migrate-state
```

### Cleaning Orphaned Resources
```bash
# Find resources in state but not in config
terraform plan | grep "destroy"

# Remove if intentionally orphaned
terraform state rm 'orphaned.resource'
```

## Parallelism Tuning

### Default Behavior
Terraform runs 10 operations in parallel by default.

```bash
# Increase parallelism
terraform apply -parallelism=30

# Decrease for rate-limited APIs
terraform apply -parallelism=5
```

### Provider-Specific Limits

| Provider | Recommended Parallelism | Notes |
|----------|------------------------|-------|
| AWS | 10-30 | Watch for rate limits |
| Azure | 10-20 | Some APIs are serial |
| GCP | 10-20 | Quota-dependent |
| Kubernetes | 5-10 | API server load |

### Rate Limit Handling
```hcl
# AWS provider with retry
provider "aws" {
  region = "eu-west-2"

  retry_mode  = "adaptive"  # Automatic backoff
  max_retries = 10
}
```

```bash
# If hitting limits, reduce parallelism
terraform apply -parallelism=5

# Or batch with targets
terraform apply -target='module.batch1' -parallelism=10
sleep 30
terraform apply -target='module.batch2' -parallelism=10
```

## Targeted Operations

### When to Use Targets
- Debugging a specific resource
- Applying urgent changes without full plan
- Working around dependency issues
- Gradual rollouts

### Target Syntax
```bash
# Single resource
terraform apply -target='aws_instance.web'

# Module
terraform apply -target='module.networking'

# Resource in module
terraform apply -target='module.app.aws_ecs_service.main'

# Multiple targets
terraform apply -target='aws_instance.web' -target='aws_lb.main'
```

### Targeted Plan
```bash
# Plan only what you're changing
terraform plan -target='module.changed' -out=targeted.tfplan

# Apply the saved plan
terraform apply targeted.tfplan
```

### Caution with Targets
- Dependencies may not be updated
- State can become inconsistent
- Always run full plan after targeted operations

```bash
# After targeted work, verify full state
terraform plan  # Should show no changes
```

## Refresh Strategies

### Refresh Behavior
By default, `terraform plan` refreshes all resources against the real world.

### Skip Refresh (When Safe)
```bash
# Skip refresh entirely
terraform plan -refresh=false

# Trust the state is current
terraform apply -refresh=false
```

**Safe when**:
- You just ran a plan/apply
- No external changes possible
- Speed is critical and risk is acceptable

### Refresh-Only Mode
```bash
# Only refresh, don't plan changes
terraform plan -refresh-only

# Update state without changing resources
terraform apply -refresh-only
```

**Use for**:
- Detecting drift
- Updating state after manual changes
- Regular state reconciliation

### Selective Refresh (Terraform 1.5+)
```hcl
# Mark resources that don't need refresh
lifecycle {
  ignore_changes = all  # Never detect drift
}
```

## Large-Scale Patterns

### Module Decomposition
```
large-project/
├── shared/              # Shared resources (separate state)
│   ├── vpc/
│   └── iam/
├── services/            # Each service has its own state
│   ├── api/
│   ├── web/
│   └── worker/
└── regions/             # Multi-region (state per region)
    ├── eu-west-2/
    └── us-east-1/
```

### Workspace Patterns for Scale
```bash
# Workspace per environment
terraform workspace new prod-eu-west-2
terraform workspace new prod-us-east-1
terraform workspace new staging

# Workspace per tenant (multi-tenant)
terraform workspace new tenant-acme
terraform workspace new tenant-corp
```

### CI/CD Optimization

**Parallel Plans**:
```yaml
# GitHub Actions example
jobs:
  plan:
    strategy:
      matrix:
        module: [networking, compute, storage]
    steps:
      - run: terraform plan -target='module.${{ matrix.module }}'
```

**Cached Providers**:
```yaml
# Cache .terraform directory
- uses: actions/cache@v4
  with:
    path: .terraform
    key: terraform-${{ hashFiles('.terraform.lock.hcl') }}
```

**Plan Artifacts**:
```bash
# Save plan for later apply
terraform plan -out=tfplan

# Apply saved plan (no recalculation)
terraform apply tfplan
```

### Blast Radius Control
```hcl
# Limit what can be destroyed
lifecycle {
  prevent_destroy = true
}
```

```bash
# Apply in stages
terraform apply -target='module.low_risk'
terraform apply -target='module.medium_risk'
terraform apply -target='module.high_risk'
```

### Monitoring Plan/Apply Times
```bash
# Track over time
echo "$(date),$(terraform plan 2>&1 | grep -c 'to add\|to change\|to destroy'),$(time terraform plan 2>&1)" >> metrics.csv
```

### Resource Limits
| Metric | Warning | Critical |
|--------|---------|----------|
| Resources per state | 100 | 200 |
| State file size | 5MB | 10MB |
| Plan time | 60s | 120s |
| Providers per config | 5 | 10 |
| Module depth | 3 | 5 |
