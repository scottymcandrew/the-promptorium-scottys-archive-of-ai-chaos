# General CI/CD Patterns

## Table of Contents
- [Pipeline Architecture](#pipeline-architecture)
- [Build Optimisation](#build-optimisation)
- [Test Strategies](#test-strategies)
- [Deployment Patterns](#deployment-patterns)
- [Secrets Management](#secrets-management)
- [Monorepo Patterns](#monorepo-patterns)
- [Container Builds](#container-builds)
- [Artifact Management](#artifact-management)

## Pipeline Architecture

### Standard Pipeline Stages
```
┌─────────┐    ┌──────┐    ┌───────────┐    ┌────────┐    ┌────────┐
│  Build  │ →  │ Test │ →  │  Analyse  │ →  │ Deploy │ →  │ Verify │
└─────────┘    └──────┘    └───────────┘    └────────┘    └────────┘
     │              │             │              │             │
   Compile      Unit tests    Security       Staging      Smoke tests
   Bundle       Integration   SAST/DAST      Production   Health checks
   Artifacts    E2E           Lint/Format    Rollback     Monitoring
```

### Pipeline Design Principles

**1. Fail Fast**
- Run quick checks first (lint, format, type-check)
- Run unit tests before integration tests
- Static analysis before deployment

**2. Parallelise Where Possible**
```
          ┌─ Lint ─────────────┐
          │                    │
Build ────┼─ Unit Tests ───────┼──→ Deploy
          │                    │
          └─ Security Scan ────┘
```

**3. Single Source of Truth**
- One pipeline definition per repo
- Environment-specific config via variables, not separate pipelines
- Promote same artifacts through environments

**4. Idempotency**
- Running pipeline twice with same input = same result
- No side effects from cancelled/retried runs

### Pipeline Types

| Type | Trigger | Purpose |
|------|---------|---------|
| **PR Pipeline** | Pull request | Validate changes before merge |
| **Main Pipeline** | Push to main | Build, test, deploy to staging |
| **Release Pipeline** | Tag/manual | Deploy to production |
| **Scheduled Pipeline** | Cron | Full regression, dependency updates |
| **Hotfix Pipeline** | Hotfix branch | Fast-track critical fixes |

## Build Optimisation

### Caching Hierarchy
```
Fastest ─────────────────────────────────────────────────────── Slowest
Local     Layer      Dependency    Build        Remote        No
Cache     Cache      Cache         Cache        Cache         Cache
```

### Dependency Caching Best Practices

**1. Cache by Lock File Hash**
```yaml
key: deps-{{ hashFiles('package-lock.json') }}
```

**2. Use Fallback Keys**
```yaml
keys:
  - deps-{{ hashFiles('package-lock.json') }}
  - deps-  # Partial cache better than none
```

**3. Cache Appropriate Paths**
| Language | What to Cache |
|----------|---------------|
| Node.js | `node_modules`, `~/.npm` |
| Python | `~/.cache/pip`, `venv` |
| Go | `~/go/pkg/mod`, `~/.cache/go-build` |
| Rust | `~/.cargo`, `target` |
| Java | `~/.m2`, `~/.gradle` |

### Incremental Builds

**Change Detection**
```bash
# Git-based: only build changed packages
git diff --name-only HEAD~1 | grep "^packages/" | cut -d/ -f2 | sort -u
```

**Build Tool Support**
- Nx: `nx affected:build`
- Turborepo: `turbo run build --filter=[HEAD^1]`
- Bazel: Native incremental
- Gradle: `--build-cache`

### Docker Build Optimisation

**1. Order Dockerfile for Caching**
```dockerfile
# Least changing first
FROM node:20-alpine

# Dependencies change less than code
COPY package*.json ./
RUN npm ci

# Code changes most often
COPY . .
RUN npm run build
```

**2. Multi-stage Builds**
```dockerfile
# Build stage
FROM node:20 AS builder
WORKDIR /app
COPY . .
RUN npm ci && npm run build

# Production stage
FROM node:20-alpine
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/node_modules /app/node_modules
CMD ["node", "/app/dist/index.js"]
```

**3. Use BuildKit**
```bash
DOCKER_BUILDKIT=1 docker build .
```

## Test Strategies

### Test Pyramid
```
         ╱╲
        ╱  ╲         E2E Tests (few, slow)
       ╱────╲
      ╱      ╲       Integration Tests (some)
     ╱────────╲
    ╱          ╲     Unit Tests (many, fast)
   ╱────────────╲
```

### Test Parallelisation

**1. Split by Timing**
```bash
# Most efficient - balances test duration
circleci tests split --split-by=timings
```

**2. Split by File**
```bash
# Simple - may be unbalanced
ls tests/*.spec.js | split -n r/$INDEX/$TOTAL
```

**3. Split by Test**
```bash
# Fine-grained - works with large test files
jest --shard=$INDEX/$TOTAL
```

### Handling Flaky Tests

**Detection**
```yaml
# Run tests multiple times to detect flakiness
- run: |
    for i in {1..5}; do
      npm test || exit 1
    done
```

**Quarantine Pattern**
```yaml
jobs:
  stable-tests:
    steps:
      - run: npm test -- --exclude-pattern="**/quarantine/**"

  flaky-tests:
    continue-on-error: true
    steps:
      - run: npm test -- --pattern="**/quarantine/**"
```

**Retry Strategy**
```yaml
# Retry flaky external dependencies, not tests
- run: |
    for i in {1..3}; do
      npm install && break
      sleep $((i * 10))
    done
```

### Test Environments

**Service Containers**
```yaml
services:
  postgres:
    image: postgres:15
    ports: [5432:5432]
  redis:
    image: redis:7
    ports: [6379:6379]
```

**Test Databases**
```bash
# Fresh database per test run
createdb "test_$(date +%s)"
```

## Deployment Patterns

### Deployment Strategies

| Strategy | Risk | Rollback | Complexity |
|----------|------|----------|------------|
| **Recreate** | High | Slow | Low |
| **Rolling** | Medium | Slow | Medium |
| **Blue-Green** | Low | Fast | Medium |
| **Canary** | Very Low | Fast | High |
| **Feature Flags** | Very Low | Instant | High |

### Blue-Green Deployment
```
        ┌────────────────┐
Users → │ Load Balancer  │
        └───────┬────────┘
                │
    ┌───────────┴───────────┐
    │                       │
┌───▼───┐              ┌────▼───┐
│ Blue  │ (current)    │ Green  │ (new)
│ v1.0  │              │ v1.1   │
└───────┘              └────────┘
```

**Steps:**
1. Deploy new version to inactive environment
2. Run smoke tests against new environment
3. Switch traffic to new environment
4. Keep old environment for quick rollback

### Canary Deployment
```yaml
# Example: Kubernetes with Istio
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  http:
  - route:
    - destination:
        host: myapp
        subset: stable
      weight: 90
    - destination:
        host: myapp
        subset: canary
      weight: 10
```

### Environment Promotion
```
┌─────────┐    ┌─────────┐    ┌────────────┐
│   Dev   │ →  │ Staging │ →  │ Production │
└─────────┘    └─────────┘    └────────────┘
     │              │               │
  On PR        On merge        On approval
  merge        to main         + tag/manual
```

### Rollback Strategies

**1. Redeploy Previous Version**
```bash
# Keep last N artifacts
./deploy.sh v1.2.3
```

**2. Kubernetes Rollback**
```bash
kubectl rollout undo deployment/myapp
kubectl rollout history deployment/myapp
```

**3. Database Considerations**
- Backward-compatible migrations only
- Separate migration and deployment steps
- Feature flags for data format changes

## Secrets Management

### Secret Hierarchy
```
Most Preferred ──────────────────────────────────────── Least Preferred
External        Cloud          CI/CD          Environment    Hardcoded
Secret Mgr      KMS            Secrets        Variables      (never)
(Vault, etc.)   (AWS/GCP/Az)   (platform)     (plain text)
```

### Secret Injection Patterns

**1. Environment Variables**
```yaml
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
```

**2. File Mounting**
```yaml
- run: |
    echo "$GCP_KEY" > /tmp/key.json
    gcloud auth activate-service-account --key-file=/tmp/key.json
    rm /tmp/key.json
```

**3. OIDC (Preferred for Cloud)**
```yaml
# No stored secrets - uses short-lived tokens
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    aws-region: eu-west-1
```

### Secret Rotation
```yaml
# Scheduled workflow to rotate secrets
on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly

jobs:
  rotate:
    steps:
      - run: ./rotate-secrets.sh
```

## Monorepo Patterns

### Change Detection
```bash
# Affected packages
CHANGED=$(git diff --name-only origin/main...HEAD)

# Filter to package directories
echo "$CHANGED" | grep "^packages/" | cut -d/ -f2 | sort -u
```

### Build Orchestration Tools

| Tool | Approach | Best For |
|------|----------|----------|
| **Nx** | Task graph, caching | JS/TS monorepos |
| **Turborepo** | Task caching | JS/TS monorepos |
| **Bazel** | Hermetic builds | Large, multi-language |
| **Pants** | Dependency graph | Python, multi-language |
| **Rush** | Package management | npm/pnpm monorepos |

### Matrix Strategy for Monorepos
```yaml
jobs:
  detect:
    outputs:
      packages: ${{ steps.detect.outputs.packages }}
    steps:
      - id: detect
        run: |
          PKGS=$(./scripts/detect-changed.sh)
          echo "packages=$PKGS" >> $GITHUB_OUTPUT

  build:
    needs: detect
    strategy:
      matrix:
        package: ${{ fromJson(needs.detect.outputs.packages) }}
    steps:
      - run: npm run build --workspace=${{ matrix.package }}
```

## Container Builds

### Multi-Architecture Builds
```yaml
- uses: docker/setup-qemu-action@v3
- uses: docker/setup-buildx-action@v3
- uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
    push: true
    tags: myapp:latest
```

### Security Scanning
```yaml
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:${{ github.sha }}
    exit-code: '1'
    severity: 'CRITICAL,HIGH'
```

### Tagging Strategy
```bash
# Tag patterns
myapp:latest          # Rolling (use with caution)
myapp:v1.2.3          # Semantic version
myapp:1.2             # Minor version track
myapp:sha-abc123      # Git SHA
myapp:pr-42           # PR builds
myapp:main-20240115   # Branch + date
```

## Artifact Management

### Artifact Types

| Type | Storage | Retention |
|------|---------|-----------|
| **Build outputs** | CI artifacts | Days |
| **Container images** | Registry | Weeks-Months |
| **Release binaries** | Release storage | Forever |
| **Test reports** | CI artifacts | Days-Weeks |

### Retention Policies
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: build
    path: dist/
    retention-days: 5  # Short for PR artifacts
```

### Artifact Promotion
```
┌────────────────┐
│ Build Artifact │
└───────┬────────┘
        │
        ▼ Tag with commit SHA
┌────────────────┐
│  Dev Registry  │
└───────┬────────┘
        │
        ▼ Retag (no rebuild)
┌────────────────┐
│ Prod Registry  │
└────────────────┘
```

```bash
# Promote without rebuild
docker tag myapp:sha-abc123 myapp:v1.2.3
docker push myapp:v1.2.3
```
