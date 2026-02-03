# CI/CD Integration

## Table of Contents
- [CI/CD Philosophy](#cicd-philosophy)
- [Pipeline Patterns](#pipeline-patterns)
- [GitHub Actions](#github-actions)
- [GitLab CI](#gitlab-ci)
- [CircleCI](#circleci)
- [Atlantis](#atlantis)
- [Security Considerations](#security-considerations)
- [Plan Artifact Strategies](#plan-artifact-strategies)

## CI/CD Philosophy

**Plans are artifacts**: Generate once, apply exactly what was reviewed.

**Authentication is external**: CI should assume roles, not store credentials.

**Approvals are mandatory**: No auto-apply to production without human review.

**State locking prevents disasters**: Concurrent applies are recipe for corruption.

## Pipeline Patterns

### Standard Flow
```
PR Created
    │
    ├──> terraform fmt -check
    ├──> terraform validate
    ├──> tflint / tfsec / checkov
    ├──> terraform plan
    │         │
    │         └──> Plan output as PR comment
    │
PR Approved + Merged
    │
    └──> terraform apply (saved plan)
```

### Multi-Environment Flow
```
PR to main
    │
    ├──> Plan: dev, staging, prod (parallel)
    │
PR Merged
    │
    ├──> Apply: dev (auto)
    ├──> Apply: staging (auto with tests)
    └──> Apply: prod (manual approval)
```

### Drift Detection
```
Scheduled (daily/weekly)
    │
    ├──> terraform plan -refresh-only
    │
    ├── No drift ──> Done
    │
    └── Drift detected ──> Alert + Optional auto-PR
```

## GitHub Actions

### Complete Workflow
```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write      # OIDC
  contents: read
  pull-requests: write  # PR comments

env:
  TF_VERSION: 1.6.0
  TF_WORKING_DIR: environments/prod

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init -backend=false
        working-directory: ${{ env.TF_WORKING_DIR }}

      - name: Terraform Validate
        run: terraform validate
        working-directory: ${{ env.TF_WORKING_DIR }}

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          soft_fail: false

      - name: checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: .
          soft_fail: false

  plan:
    runs-on: ubuntu-latest
    needs: [validate, security]
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActions-TerraformPlan
          aws-region: eu-west-2

      - name: Terraform Init
        run: terraform init
        working-directory: ${{ env.TF_WORKING_DIR }}

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -no-color -out=tfplan 2>&1 | tee plan.txt
          echo "plan<<EOF" >> $GITHUB_OUTPUT
          cat plan.txt >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
        working-directory: ${{ env.TF_WORKING_DIR }}
        continue-on-error: true

      - name: Upload Plan Artifact
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: ${{ env.TF_WORKING_DIR }}/tfplan

      - name: Comment PR
        uses: actions/github-script@v7
        with:
          script: |
            const output = `### Terraform Plan
            \`\`\`
            ${{ steps.plan.outputs.plan }}
            \`\`\`
            `;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output.substring(0, 65000) // GitHub limit
            });

      - name: Fail if Plan Failed
        if: steps.plan.outcome == 'failure'
        run: exit 1

  apply:
    runs-on: ubuntu-latest
    needs: [plan]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production  # Requires approval
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActions-TerraformApply
          aws-region: eu-west-2

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan
          path: ${{ env.TF_WORKING_DIR }}

      - name: Terraform Init
        run: terraform init
        working-directory: ${{ env.TF_WORKING_DIR }}

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        working-directory: ${{ env.TF_WORKING_DIR }}
```

### OIDC Configuration (AWS)
```hcl
# GitHub OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Role for Terraform
resource "aws_iam_role" "github_actions_terraform" {
  name = "GitHubActions-Terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Attach appropriate policies
resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = aws_iam_policy.terraform_permissions.arn
}
```

## GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - plan
  - apply

variables:
  TF_VERSION: "1.6.0"
  TF_ROOT: "environments/prod"

image:
  name: hashicorp/terraform:$TF_VERSION
  entrypoint: [""]

cache:
  key: terraform-providers
  paths:
    - .terraform/

before_script:
  - cd $TF_ROOT
  - terraform init

validate:
  stage: validate
  script:
    - terraform fmt -check -recursive
    - terraform validate
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

plan:
  stage: plan
  script:
    - terraform plan -out=tfplan
    - terraform show -no-color tfplan > plan.txt
  artifacts:
    paths:
      - $TF_ROOT/tfplan
      - $TF_ROOT/plan.txt
    expire_in: 7 days
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

apply:
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
  dependencies:
    - plan
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  when: manual
  environment:
    name: production
```

## CircleCI

```yaml
# .circleci/config.yml
version: 2.1

orbs:
  terraform: circleci/terraform@3.2

executors:
  terraform:
    docker:
      - image: hashicorp/terraform:1.6.0

jobs:
  validate:
    executor: terraform
    steps:
      - checkout
      - run:
          name: Terraform Format
          command: terraform fmt -check -recursive
      - run:
          name: Terraform Init
          command: terraform init -backend=false
          working_directory: environments/prod
      - run:
          name: Terraform Validate
          command: terraform validate
          working_directory: environments/prod

  plan:
    executor: terraform
    steps:
      - checkout
      - run:
          name: Terraform Init
          command: terraform init
          working_directory: environments/prod
      - run:
          name: Terraform Plan
          command: terraform plan -out=tfplan
          working_directory: environments/prod
      - persist_to_workspace:
          root: .
          paths:
            - environments/prod/tfplan
            - environments/prod/.terraform

  apply:
    executor: terraform
    steps:
      - checkout
      - attach_workspace:
          at: .
      - run:
          name: Terraform Apply
          command: terraform apply -auto-approve tfplan
          working_directory: environments/prod

workflows:
  terraform:
    jobs:
      - validate
      - plan:
          requires:
            - validate
          filters:
            branches:
              only: main
      - hold:
          type: approval
          requires:
            - plan
      - apply:
          requires:
            - hold
```

## Atlantis

Self-hosted Terraform automation.

### atlantis.yaml
```yaml
version: 3
projects:
  - name: networking
    dir: environments/prod/networking
    workspace: default
    autoplan:
      when_modified:
        - "*.tf"
        - "*.tfvars"
      enabled: true
    apply_requirements:
      - approved
      - mergeable

  - name: compute
    dir: environments/prod/compute
    workspace: default
    autoplan:
      when_modified:
        - "*.tf"
      enabled: true
    apply_requirements:
      - approved
```

### Server Configuration
```yaml
# repos.yaml
repos:
  - id: github.com/myorg/infrastructure
    allowed_overrides:
      - apply_requirements
      - workflow
    apply_requirements:
      - approved
      - mergeable
    workflow: default

workflows:
  default:
    plan:
      steps:
        - init
        - plan:
            extra_args: ["-lock=false"]
    apply:
      steps:
        - apply
```

## Security Considerations

### Least Privilege Roles
```hcl
# Separate roles for plan vs apply
resource "aws_iam_role" "terraform_plan" {
  name = "TerraformPlan"
  # Read-only permissions
}

resource "aws_iam_role" "terraform_apply" {
  name = "TerraformApply"
  # Full permissions, but scoped
}
```

### Secrets Management
```yaml
# Use secrets managers, not env vars
- name: Get Secrets
  uses: aws-actions/aws-secretsmanager-get-secrets@v2
  with:
    secret-ids: |
      TF_VAR_database_password,prod/database/password

- name: Terraform Apply
  run: terraform apply -auto-approve
  env:
    TF_VAR_database_password: ${{ env.TF_VAR_database_password }}
```

### Audit Logging
```hcl
# Log all Terraform operations
resource "aws_cloudtrail" "terraform" {
  name           = "terraform-audit"
  s3_bucket_name = aws_s3_bucket.audit_logs.id

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
```

## Plan Artifact Strategies

### Binary Plan Files
```bash
# Generate binary plan
terraform plan -out=tfplan

# Upload as artifact
# Apply later with exact same plan
terraform apply tfplan
```

**Pros**: Guaranteed same changes, includes provider binaries
**Cons**: Large files, platform-specific

### JSON Plan Files
```bash
# Generate JSON
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json

# Use for review and policy
opa eval --data policies/ --input tfplan.json "data.terraform.deny"
```

**Pros**: Human-readable, policy-checkable
**Cons**: Can't apply directly, may drift

### Recommended Pattern
```yaml
# 1. Generate and save binary plan
- run: terraform plan -out=tfplan

# 2. Also generate JSON for review
- run: terraform show -json tfplan > tfplan.json

# 3. Upload both
- uses: actions/upload-artifact@v4
  with:
    name: terraform-plan
    path: |
      tfplan
      tfplan.json

# 4. Apply uses binary plan
- run: terraform apply tfplan
```

### Plan Expiration
```yaml
# Plans should have short TTL
artifacts:
  paths:
    - tfplan
  expire_in: 24 hours  # Don't apply stale plans
```
