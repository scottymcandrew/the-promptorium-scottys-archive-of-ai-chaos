# CI/CD Troubleshooting Workflows

## Table of Contents
- [Diagnostic Approach](#diagnostic-approach)
- [Build Failures](#build-failures)
- [Test Failures](#test-failures)
- [Deployment Failures](#deployment-failures)
- [Performance Issues](#performance-issues)
- [Infrastructure Issues](#infrastructure-issues)
- [Platform-Specific Quirks](#platform-specific-quirks)

## Diagnostic Approach

### Universal Triage Order

When facing any CI/CD failure:

**1. Read the error message**
- Full error, not just the last line
- Exit code (non-zero = failure)
- Stack trace if available

**2. Identify the layer**
```
┌─────────────────────────────────────────────────────────────┐
│                      CI Platform                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  Execution Environment                 │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │                   Build Tool                     │  │  │
│  │  │  ┌───────────────────────────────────────────┐  │  │  │
│  │  │  │              Your Code                     │  │  │  │
│  │  │  └───────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**3. Check what changed**
- Recent commits
- Config changes
- Dependency updates
- Platform changes (runner images, etc.)

**4. Reproduce locally if possible**
- Same commands, same environment
- Docker for environment parity

**5. Isolate the failure**
- Which job? Which step? Which command?
- Does it fail consistently or intermittently?

### Information to Gather

```markdown
## Failure Report

**Pipeline URL:** [link]
**Job:** [name]
**Step:** [name/number]

**Error:**
```
[exact error message]
```

**Exit Code:** [number]

**Recent Changes:**
- [ ] Code changes
- [ ] Config changes
- [ ] Dependency updates
- [ ] No changes (flaky?)

**Reproducible:**
- [ ] Every time
- [ ] Intermittent
- [ ] First occurrence

**Environment:**
- Runner: [type]
- Container: [image if applicable]
- Relevant versions: [language, tools]
```

## Build Failures

### Dependency Installation Failures

**"Could not resolve dependencies"**
```
npm ERR! peer dep missing: react@^18, required by some-package@1.0.0
```

**Causes:**
1. Lock file out of sync with package.json
2. Registry unavailable
3. Peer dependency conflicts
4. Private package auth failure

**Fixes:**
```bash
# Regenerate lock file
rm package-lock.json && npm install

# Check registry status
npm ping

# Force resolution (careful!)
npm install --legacy-peer-deps

# Private packages - check auth
npm whoami --registry=https://npm.pkg.github.com
```

### "Command not found"

```
bash: some-tool: command not found
```

**Causes:**
1. Tool not installed in environment
2. PATH not set correctly
3. Wrong shell (sh vs bash)

**Fixes:**
```yaml
# Install missing tool
- run: |
    sudo apt-get update
    sudo apt-get install -y some-tool

# Or use container with tool
container:
  image: some-image-with-tool

# Check PATH
- run: echo $PATH && which some-tool
```

### "Out of memory"

```
FATAL ERROR: Reached heap limit Allocation failed - JavaScript heap out of memory
```

**Fixes:**
```yaml
# Increase Node.js memory
env:
  NODE_OPTIONS: --max-old-space-size=8192

# Use larger runner
runs-on: ubuntu-latest-8-cores

# Or reduce parallelism
- run: npm test -- --maxWorkers=2
```

### "No space left on device"

```
ENOSPC: no space left on device
```

**Fixes:**
```yaml
# Clean up before heavy operations
- run: |
    df -h
    sudo rm -rf /usr/share/dotnet
    sudo rm -rf /opt/ghc
    sudo rm -rf /usr/local/share/boost
    sudo docker system prune -af
    df -h
```

### Compilation Errors

**Debugging steps:**
1. Check language/compiler version matches local
2. Check for missing build dependencies
3. Verify environment variables
4. Check for platform-specific code issues (Windows vs Linux)

```yaml
# Version debugging
- run: |
    node --version
    npm --version
    gcc --version
    env | grep -E 'NODE_|NPM_|CC|CXX'
```

## Test Failures

### Tests Pass Locally, Fail in CI

**Common causes and fixes:**

| Cause | Symptom | Fix |
|-------|---------|-----|
| Timing | "Timeout waiting for..." | Increase timeouts, add retries |
| Environment | Different behaviour | Match CI env locally (Docker) |
| File paths | "File not found" | Use relative/cross-platform paths |
| Locale | Date/number format issues | Set explicit locale |
| Timezone | Time-based assertions fail | Use UTC, mock time |
| Ordering | Passes alone, fails in suite | Isolate test state |
| Resources | Connection refused | Wait for services to start |

```yaml
# Timezone
env:
  TZ: UTC

# Locale
env:
  LC_ALL: C.UTF-8

# Wait for service
- run: |
    until pg_isready -h localhost -p 5432; do
      sleep 1
    done
```

### Flaky Tests

**Detection:**
```yaml
# Run multiple times
- run: |
    for i in {1..5}; do
      npm test 2>&1 | tee -a test-output.log
      if [ $? -ne 0 ]; then
        echo "Failed on run $i"
        exit 1
      fi
    done
```

**Common causes:**
1. Race conditions in async code
2. Shared state between tests
3. Time-dependent assertions
4. External service dependencies
5. Random ordering exposing hidden dependencies

**Fixes:**
```javascript
// Bad - shared state
let counter = 0;
beforeEach(() => { /* doesn't reset counter */ });

// Good - isolated state
beforeEach(() => { counter = 0; });

// Bad - timing dependent
await sleep(100);
expect(result).toBe(expected);

// Good - wait for condition
await waitFor(() => expect(result).toBe(expected));
```

### Test Timeout

```
Timeout - Async callback was not invoked within 5000ms
```

**Causes:**
1. Test actually takes longer than timeout
2. Async operation never completes
3. Unhandled promise rejection
4. Wrong async pattern

**Fixes:**
```javascript
// Increase timeout for slow tests
test('slow operation', async () => {
  // ...
}, 30000);

// Ensure promises are awaited
test('async test', async () => {
  await expect(asyncFn()).resolves.toBe(true);
});

// Check for hanging connections
afterAll(async () => {
  await db.close();
  await server.close();
});
```

## Deployment Failures

### Authentication Failures

```
Error: The security token included in the request is expired
```

**Causes:**
1. Credentials expired
2. Token needs refresh
3. Wrong credentials for environment
4. Missing permissions

**Debugging:**
```yaml
# Check identity
- run: |
    aws sts get-caller-identity
    # or
    az account show
    # or
    gcloud auth list
```

**Fixes:**
```yaml
# Use OIDC instead of static credentials
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    aws-region: eu-west-1
```

### "Resource not found"

```
ResourceNotFoundException: Function not found: arn:aws:lambda:...
```

**Causes:**
1. Wrong environment/account
2. Resource not yet created
3. Name mismatch

**Debugging:**
```yaml
- run: |
    echo "Account: $(aws sts get-caller-identity --query Account --output text)"
    echo "Region: $AWS_REGION"
    aws lambda list-functions --query 'Functions[].FunctionName'
```

### Health Check Failures

```
Deployment failed: Health checks failed
```

**Causes:**
1. Application crashes on startup
2. Wrong health endpoint
3. Port mismatch
4. Insufficient resources

**Debugging:**
```yaml
- run: |
    # Check container logs
    kubectl logs deployment/myapp --tail=100

    # Check events
    kubectl get events --sort-by=.lastTimestamp

    # Check resource usage
    kubectl top pods

    # Manual health check
    kubectl exec deploy/myapp -- curl -v localhost:8080/health
```

### Rollback Required

**When to rollback:**
1. Health checks failing after deploy
2. Error rate spike in monitoring
3. Critical functionality broken

**How to rollback:**
```bash
# Kubernetes
kubectl rollout undo deployment/myapp

# AWS ECS
aws ecs update-service --cluster mycluster --service myservice \
  --task-definition myapp:previous-version

# Manual (redeploy previous artifact)
./deploy.sh v1.2.2  # Previous version
```

## Performance Issues

### Slow Pipeline

**Diagnostic steps:**
1. Identify slowest jobs/steps
2. Check for unnecessary work
3. Look for caching opportunities
4. Consider parallelisation

**Common optimisations:**

| Issue | Solution | Impact |
|-------|----------|--------|
| No caching | Add dependency caching | 30-60% faster |
| Serial jobs | Parallelise independent jobs | 40-70% faster |
| Full rebuilds | Incremental builds | 50-80% faster |
| Large images | Use slim/alpine images | 20-40% faster |
| No layer cache | Docker layer caching | 50-80% faster |

### Cache Not Working

**Symptoms:**
- Cache restore always misses
- Cache save fails
- Incorrect files cached

**Debugging:**
```yaml
- run: |
    echo "Cache key: deps-${{ hashFiles('package-lock.json') }}"
    ls -la ~/.npm || echo "Cache directory missing"
    du -sh ~/.npm || echo "Cannot measure cache"
```

**Common issues:**
1. Lock file changes every run (regenerated)
2. Wrong paths cached
3. Cache size exceeds limit
4. Key too specific (never matches)

## Infrastructure Issues

### Runner Unavailable

```
No runner matching the specified labels was found
```

**Causes:**
1. Self-hosted runner offline
2. Label mismatch
3. All runners busy

**Fixes:**
```yaml
# Check runner status
# Settings → Actions → Runners

# Use fallback
runs-on: [self-hosted, linux, x64]
# becomes
runs-on: ubuntu-latest
```

### Rate Limiting

```
API rate limit exceeded
```

**Causes:**
1. Too many API calls
2. Too many workflow runs
3. Package registry limits

**Fixes:**
```yaml
# Use GITHUB_TOKEN for authenticated rate limits
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

# Add delays between calls
- run: |
    for item in $items; do
      ./process.sh $item
      sleep 1
    done

# Use concurrency to limit parallel runs
concurrency:
  group: api-calls
  cancel-in-progress: false
```

### Network Issues

```
Could not connect to registry.npmjs.org
```

**Causes:**
1. Registry down
2. Network policy blocking
3. DNS issues
4. Proxy misconfiguration

**Debugging:**
```yaml
- run: |
    # DNS
    nslookup registry.npmjs.org

    # Connectivity
    curl -v https://registry.npmjs.org/

    # Proxy
    echo "HTTP_PROXY: $HTTP_PROXY"
    echo "HTTPS_PROXY: $HTTPS_PROXY"
```

## Platform-Specific Quirks

### CircleCI

| Issue | Cause | Fix |
|-------|-------|-----|
| SSH keys not found | Keys not in project settings | Add via Project Settings → SSH Keys |
| Context not accessible | Wrong org or restricted | Check context org and security groups |
| Config validation fails | Orb version issues | Pin orb versions explicitly |
| Cache not restoring | Corrupted or key changed | Bump cache key version |

### GitHub Actions

| Issue | Cause | Fix |
|-------|-------|-----|
| "Resource not accessible" | Missing permissions | Add `permissions` block |
| Secret empty | Fork PR (no secret access) | Use `pull_request_target` carefully |
| Workflow not triggered | Path filter too strict | Check `paths` and `paths-ignore` |
| Cancelled unexpectedly | Concurrency group | Check `concurrency` settings |
| Expression evaluation error | Context not available | Check context scope |

### Common Cross-Platform Issues

**Windows vs Linux:**
```yaml
# Path separators
- run: |
    # Linux
    ./scripts/build.sh

    # Windows
    .\scripts\build.ps1

# Use cross-platform
- run: node scripts/build.js
  shell: bash  # Force bash on Windows too
```

**Shell differences:**
```yaml
# Specify shell explicitly
- run: |
    echo "Using bash"
  shell: bash

# PowerShell for Windows
- run: |
    Write-Output "Using PowerShell"
  shell: pwsh
```

**Line endings:**
```yaml
# Ensure consistent line endings
- run: |
    git config --global core.autocrlf input
```
