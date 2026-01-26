# GitHub Actions Reference

## Table of Contents
- [Configuration Structure](#configuration-structure)
- [Common Errors](#common-errors)
- [Debugging Techniques](#debugging-techniques)
- [Caching Strategies](#caching-strategies)
- [Matrix Builds](#matrix-builds)
- [Reusable Workflows](#reusable-workflows)
- [Secrets & Environments](#secrets--environments)
- [Runner Types](#runner-types)
- [Workflow Patterns](#workflow-patterns)
- [Security Considerations](#security-considerations)

## Configuration Structure

### Basic Structure
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/

  test:
    needs: build
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: build
          path: dist/

      - run: npm test
```

### Trigger Events
```yaml
on:
  # Push to branches
  push:
    branches: [main, 'release/**']
    paths: ['src/**', 'package.json']
    tags: ['v*']

  # Pull requests
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main]

  # Manual trigger
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

  # Scheduled
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily

  # Called by another workflow
  workflow_call:
    inputs:
      version:
        required: true
        type: string
    secrets:
      npm_token:
        required: true
```

## Common Errors

### "Resource not accessible by integration"
```
Error: Resource not accessible by integration
```
**Causes:**
1. GITHUB_TOKEN lacks required permissions
2. Workflow triggered by fork PR (restricted permissions)
3. Required permission not declared

**Fix:** Add explicit permissions
```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

### "No space left on device"
```
ENOSPC: no space left on device
```
**Fix:** Free up space before heavy operations
```yaml
- name: Free disk space
  run: |
    sudo rm -rf /usr/share/dotnet
    sudo rm -rf /opt/ghc
    sudo rm -rf /usr/local/share/boost
    df -h
```

### "Node.js 12 actions are deprecated"
```
Node.js 12 actions are deprecated
```
**Fix:** Update to latest action versions
```yaml
# Old
- uses: actions/checkout@v2

# New
- uses: actions/checkout@v4
```

### "The template is not valid"
```
The workflow is not valid. .github/workflows/ci.yml: Unexpected value 'env'
```
**Common causes:**
1. YAML syntax error (indentation, quotes)
2. Wrong key placement
3. Invalid expression syntax

**Debug:** Use workflow editor in GitHub UI for syntax highlighting

### "Context access might be invalid"
```
Unrecognized named-value: 'env'
```
**Cause:** Using context in wrong scope
```yaml
# Wrong - env context not available in job-level if
jobs:
  build:
    if: ${{ env.SHOULD_RUN == 'true' }}  # Fails

# Correct - use job output or workflow-level env
jobs:
  check:
    outputs:
      should_run: ${{ steps.check.outputs.result }}
    steps:
      - id: check
        run: echo "result=true" >> $GITHUB_OUTPUT

  build:
    needs: check
    if: ${{ needs.check.outputs.should_run == 'true' }}
```

### "Secret not found"
```
Error: Value cannot be null (secret)
```
**Causes:**
1. Secret not created in repository/environment
2. Typo in secret name
3. Fork PR cannot access secrets

**Fix:** Check secret exists in Settings → Secrets and variables → Actions

### "Workflow cancelled"
```
The workflow was cancelled
```
**Causes:**
1. Newer commit triggered new run
2. Manual cancellation
3. Concurrency group cancellation

**Check:** Look at workflow runs for cancellation source

## Debugging Techniques

### Enable Debug Logging
```yaml
# Set these secrets in repository settings
# ACTIONS_RUNNER_DEBUG: true
# ACTIONS_STEP_DEBUG: true
```

Or via `gh` CLI:
```bash
gh run rerun RUN_ID --debug
```

### Debug Step
```yaml
- name: Debug info
  run: |
    echo "Event: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "SHA: ${{ github.sha }}"
    echo "Actor: ${{ github.actor }}"
    echo "Workflow: ${{ github.workflow }}"
    echo "Run ID: ${{ github.run_id }}"
    echo "Run number: ${{ github.run_number }}"
    env | sort
```

### Dump Contexts
```yaml
- name: Dump GitHub context
  env:
    GITHUB_CONTEXT: ${{ toJson(github) }}
  run: echo "$GITHUB_CONTEXT"

- name: Dump job context
  env:
    JOB_CONTEXT: ${{ toJson(job) }}
  run: echo "$JOB_CONTEXT"

- name: Dump steps context
  env:
    STEPS_CONTEXT: ${{ toJson(steps) }}
  run: echo "$STEPS_CONTEXT"
```

### SSH Access (tmate)
```yaml
- name: Setup tmate session
  if: ${{ failure() }}
  uses: mxschmitt/action-tmate@v3
  timeout-minutes: 15
```

### Local Testing with act
```bash
# Install act
brew install act

# Run workflow locally
act push

# Run specific job
act -j build

# With secrets
act -s GITHUB_TOKEN="$(gh auth token)"

# List workflows
act -l
```

## Caching Strategies

### Built-in Action Caching
```yaml
# Node.js
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'  # Also: yarn, pnpm

# Python
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
    cache: 'pip'

# Go
- uses: actions/setup-go@v5
  with:
    go-version: '1.22'
    cache: true
```

### Manual Caching
```yaml
- name: Cache dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      node_modules
    key: deps-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      deps-${{ runner.os }}-
```

### Cache Patterns by Language
```yaml
# Rust
- uses: actions/cache@v4
  with:
    path: |
      ~/.cargo/bin/
      ~/.cargo/registry/index/
      ~/.cargo/registry/cache/
      ~/.cargo/git/db/
      target/
    key: cargo-${{ runner.os }}-${{ hashFiles('**/Cargo.lock') }}

# Gradle
- uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
```

### Cache Limits
- Maximum cache size: 10GB per repository
- Caches not accessed in 7 days are evicted
- When limit exceeded, oldest caches evicted first

## Matrix Builds

### Basic Matrix
```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node: [18, 20, 22]

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm test
```

### Matrix with Include/Exclude
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    node: [18, 20]
    exclude:
      - os: windows-latest
        node: 18
    include:
      - os: ubuntu-latest
        node: 20
        experimental: true
```

### Fail-Fast Control
```yaml
strategy:
  fail-fast: false  # Continue other matrix jobs if one fails
  matrix:
    version: [10, 12, 14]
```

### Dynamic Matrix
```yaml
jobs:
  prepare:
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - id: set-matrix
        run: |
          echo 'matrix={"include":[{"version":"1.0"},{"version":"2.0"}]}' >> $GITHUB_OUTPUT

  build:
    needs: prepare
    strategy:
      matrix: ${{ fromJson(needs.prepare.outputs.matrix) }}
    steps:
      - run: echo "Building version ${{ matrix.version }}"
```

## Reusable Workflows

### Define Reusable Workflow
```yaml
# .github/workflows/reusable-build.yml
name: Reusable Build

on:
  workflow_call:
    inputs:
      node-version:
        required: false
        type: string
        default: '20'
    secrets:
      npm-token:
        required: false
    outputs:
      artifact-name:
        description: "Name of the uploaded artifact"
        value: ${{ jobs.build.outputs.artifact-name }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      artifact-name: ${{ steps.upload.outputs.artifact-name }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
      - run: npm ci
        env:
          NPM_TOKEN: ${{ secrets.npm-token }}
      - run: npm run build
      - id: upload
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: dist/
```

### Call Reusable Workflow
```yaml
# .github/workflows/ci.yml
jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '20'
    secrets:
      npm-token: ${{ secrets.NPM_TOKEN }}

  # Or from another repo
  build-external:
    uses: org/repo/.github/workflows/reusable-build.yml@main
    secrets: inherit  # Pass all secrets
```

## Secrets & Environments

### Secret Types
| Type | Scope | Access |
|------|-------|--------|
| Repository secrets | Single repo | All workflows |
| Environment secrets | Environment | Jobs using environment |
| Organization secrets | Org repos | Selected repos |

### Using Environments
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://myapp.com
    steps:
      - name: Deploy
        env:
          API_KEY: ${{ secrets.PROD_API_KEY }}  # Environment secret
        run: ./deploy.sh
```

### Environment Protection Rules
- Required reviewers
- Wait timer
- Branch restrictions
- Custom deployment protection rules

### Masking Secrets in Logs
```yaml
- name: Mask a value
  run: |
    MY_SECRET=$(fetch_secret)
    echo "::add-mask::$MY_SECRET"
    echo "Using secret: $MY_SECRET"  # Will show ***
```

## Runner Types

### GitHub-Hosted Runners
| Runner | vCPUs | RAM | Storage |
|--------|-------|-----|---------|
| `ubuntu-latest` | 4 | 16GB | 14GB |
| `ubuntu-24.04` | 4 | 16GB | 14GB |
| `macos-latest` | 3 | 14GB | 14GB |
| `macos-14` (M1) | 3 | 7GB | 14GB |
| `windows-latest` | 4 | 16GB | 14GB |

### Larger Runners (Team/Enterprise)
```yaml
runs-on: ubuntu-latest-8-cores  # Example naming
```

### Self-Hosted Runners
```yaml
runs-on: [self-hosted, linux, x64, gpu]

# Or with labels
runs-on:
  group: my-runner-group
  labels: [linux, x64]
```

### Container Jobs
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: node:20
      credentials:
        username: ${{ secrets.DOCKER_USER }}
        password: ${{ secrets.DOCKER_PASSWORD }}
      env:
        NODE_ENV: production
      volumes:
        - my_docker_volume:/volume_mount
```

### Service Containers
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        ports:
          - 6379:6379
```

## Workflow Patterns

### Concurrency Control
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # Cancel previous runs for same branch
```

### Conditional Execution
```yaml
jobs:
  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    steps:
      - name: Only on success
        if: success()

      - name: Only on failure
        if: failure()

      - name: Always run
        if: always()

      - name: With expression
        if: ${{ contains(github.event.head_commit.message, '[deploy]') }}
```

### Job Dependencies
```yaml
jobs:
  build:
    runs-on: ubuntu-latest

  test:
    needs: build
    runs-on: ubuntu-latest

  deploy:
    needs: [build, test]
    if: ${{ needs.build.result == 'success' && needs.test.result == 'success' }}
```

### Path Filtering
```yaml
on:
  push:
    paths:
      - 'src/**'
      - 'package.json'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

### Manual Approval
```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh staging

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production  # Has required reviewers
    steps:
      - run: ./deploy.sh production
```

## Security Considerations

### Permissions (Principle of Least Privilege)
```yaml
# Workflow-level (restrictive)
permissions:
  contents: read

jobs:
  build:
    # Job-level (override if needed)
    permissions:
      contents: read
      packages: write
```

### Fork PR Security
```yaml
# Safer for fork PRs
on:
  pull_request_target:  # Runs in base repo context
    types: [labeled]

jobs:
  build:
    if: contains(github.event.pull_request.labels.*.name, 'safe to test')
    runs-on: ubuntu-latest
```

### Script Injection Prevention
```yaml
# Dangerous - user input in script
- run: echo "${{ github.event.issue.title }}"  # Could inject commands

# Safe - use environment variable
- env:
    TITLE: ${{ github.event.issue.title }}
  run: echo "$TITLE"
```

### Dependency Pinning
```yaml
# Pin to full SHA, not tag
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

### OpenID Connect (OIDC)
```yaml
# Authenticate to cloud providers without stored secrets
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/github-actions
      aws-region: eu-west-1
```
