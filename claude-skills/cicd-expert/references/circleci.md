# CircleCI Reference

## Table of Contents
- [Configuration Structure](#configuration-structure)
- [Common Errors](#common-errors)
- [Debugging Techniques](#debugging-techniques)
- [Caching Strategies](#caching-strategies)
- [Parallelism & Test Splitting](#parallelism--test-splitting)
- [Orbs](#orbs)
- [Contexts & Secrets](#contexts--secrets)
- [Resource Classes](#resource-classes)
- [Workflow Patterns](#workflow-patterns)

## Configuration Structure

### Basic Structure
```yaml
version: 2.1

orbs:
  node: circleci/node@5.2.0

executors:
  default:
    docker:
      - image: cimg/node:20.10
    resource_class: medium

commands:
  install-deps:
    steps:
      - checkout
      - restore_cache:
          keys:
            - deps-v1-{{ checksum "package-lock.json" }}
      - run: npm ci
      - save_cache:
          key: deps-v1-{{ checksum "package-lock.json" }}
          paths:
            - node_modules

jobs:
  build:
    executor: default
    steps:
      - install-deps
      - run: npm run build
      - persist_to_workspace:
          root: .
          paths:
            - dist

  test:
    executor: default
    parallelism: 4
    steps:
      - install-deps
      - attach_workspace:
          at: .
      - run:
          name: Run tests
          command: |
            circleci tests glob "src/**/*.test.ts" | \
            circleci tests split --split-by=timings | \
            xargs npm test --

workflows:
  build-and-test:
    jobs:
      - build
      - test:
          requires:
            - build
```

### Key Configuration Elements

| Element | Purpose | Scope |
|---------|---------|-------|
| `orbs` | Reusable packages of config | Project |
| `executors` | Execution environment definitions | Project |
| `commands` | Reusable step sequences | Project |
| `jobs` | Units of work with steps | Workflow |
| `workflows` | Orchestration of jobs | Pipeline |

## Common Errors

### "No configuration was found"
```
Configuration file not found at .circleci/config.yml
```
**Cause:** Missing or misnamed config file
**Fix:** Ensure `.circleci/config.yml` exists (note: `.yml` not `.yaml`)

### "Cannot find a job named X"
```yaml
# Wrong - job name mismatch
workflows:
  main:
    jobs:
      - buid  # Typo

jobs:
  build:  # Actual name
```
**Fix:** Match job names exactly (case-sensitive)

### "Executor not found"
```
Executor 'my-executor' not found
```
**Causes:**
1. Executor defined in orb but orb not imported
2. Typo in executor name
3. Executor defined after use

**Fix:** Check orb imports, verify names, check ordering

### "Resource class not available"
```
Resource class 'xlarge' is not available on your plan
```
**Fix:** Use available resource class or upgrade plan
```yaml
resource_class: medium  # Available on all plans
```

### "Caching error: failed to restore cache"
```
Skipping cache - errorass unarchiving layer
```
**Causes:**
1. Corrupted cache
2. Disk space issues
3. Version mismatch in cached tools

**Fix:** Change cache key version
```yaml
keys:
  - deps-v2-{{ checksum "package-lock.json" }}  # Bump v1 to v2
```

### "Cannot checkout: SSH key not found"
```
Permission denied (publickey)
```
**Causes:**
1. Deploy key not added
2. User key required for submodules
3. Private repo access needed

**Fix:** Add SSH key in project settings or use checkout with SSH keys
```yaml
- add_ssh_keys:
    fingerprints:
      - "SO:ME:FI:NG:ER:PR:IN:T"
- checkout
```

### "Context not found"
```
Context 'production' not found in org
```
**Causes:**
1. Context doesn't exist
2. Context in different org
3. No access to restricted context

**Fix:** Create context or fix org/access

### "Out of memory"
```
FATAL ERROR: CALL_AND_RETRY_LAST Allocation failed - JavaScript heap out of memory
```
**Fix:** Increase resource class or memory allocation
```yaml
resource_class: large

# Or for Node.js
- run:
    command: npm run build
    environment:
      NODE_OPTIONS: --max-old-space-size=4096
```

## Debugging Techniques

### SSH into Failed Build
1. Click "Rerun" → "Rerun Job with SSH"
2. Wait for SSH details in output
3. Connect: `ssh -p PORT IP_ADDRESS`
4. Debug in `/home/circleci/project`

### Enable Debug Logging
```yaml
- run:
    name: Debug step
    command: |
      set -x  # Bash debug mode
      env | sort  # Show all env vars
      pwd && ls -la
```

### Check Config Locally
```bash
# Validate config
circleci config validate

# Process config (expand orbs, etc.)
circleci config process .circleci/config.yml

# Run job locally (limited support)
circleci local execute --job build
```

### Useful Environment Variables
```bash
# Built-in variables
echo $CIRCLE_SHA1           # Git commit SHA
echo $CIRCLE_BRANCH         # Branch name
echo $CIRCLE_TAG            # Tag name (if tagged build)
echo $CIRCLE_BUILD_NUM      # Build number
echo $CIRCLE_PR_NUMBER      # PR number (if PR)
echo $CIRCLE_JOB            # Job name
echo $CIRCLE_NODE_INDEX     # Parallelism index (0-based)
echo $CIRCLE_NODE_TOTAL     # Total parallel containers
```

## Caching Strategies

### Dependency Caching
```yaml
# Node.js
- restore_cache:
    keys:
      - node-deps-v1-{{ checksum "package-lock.json" }}
      - node-deps-v1-  # Fallback to any node-deps-v1 cache
- run: npm ci
- save_cache:
    key: node-deps-v1-{{ checksum "package-lock.json" }}
    paths:
      - node_modules

# Python
- restore_cache:
    keys:
      - pip-deps-v1-{{ checksum "requirements.txt" }}
- run: pip install -r requirements.txt
- save_cache:
    key: pip-deps-v1-{{ checksum "requirements.txt" }}
    paths:
      - ~/.cache/pip
      - venv

# Go
- restore_cache:
    keys:
      - go-mod-v1-{{ checksum "go.sum" }}
- run: go mod download
- save_cache:
    key: go-mod-v1-{{ checksum "go.sum" }}
    paths:
      - /home/circleci/go/pkg/mod
```

### Cache Key Templates
```yaml
# Available templates
{{ checksum "file" }}           # File hash
{{ .Branch }}                   # Branch name
{{ .Revision }}                 # Git SHA
{{ .Environment.MY_VAR }}       # Env var value
{{ epoch }}                     # Unix timestamp
{{ arch }}                      # CPU architecture
```

### Cache Best Practices
- Use multiple fallback keys (most specific to least)
- Include version prefix for easy invalidation
- Don't cache build outputs (use workspaces)
- Cache size limit: 3GB per key

## Parallelism & Test Splitting

### Enable Parallelism
```yaml
jobs:
  test:
    parallelism: 4  # Run 4 containers
    steps:
      - run:
          name: Split and run tests
          command: |
            TESTS=$(circleci tests glob "tests/**/*.py" | circleci tests split)
            pytest $TESTS
```

### Split Strategies
```bash
# By timing data (best - requires historical data)
circleci tests split --split-by=timings

# By file size
circleci tests split --split-by=filesize

# Evenly by count (default)
circleci tests split

# With timing file
circleci tests split --split-by=timings --timings-type=filename
```

### Store Timing Data
```yaml
- store_test_results:
    path: test-results  # JUnit XML format
```

## Orbs

### Using Orbs
```yaml
orbs:
  node: circleci/node@5.2.0
  aws-cli: circleci/aws-cli@4.1.2
  slack: circleci/slack@4.12.5

jobs:
  build:
    executor: node/default
    steps:
      - node/install-packages
      - run: npm test
      - slack/notify:
          event: fail
          template: basic_fail_1
```

### Common Orbs
| Orb | Purpose |
|-----|---------|
| `circleci/node` | Node.js builds |
| `circleci/python` | Python builds |
| `circleci/go` | Go builds |
| `circleci/docker` | Docker build/push |
| `circleci/aws-cli` | AWS operations |
| `circleci/aws-ecr` | ECR push |
| `circleci/aws-ecs` | ECS deploy |
| `circleci/gcp-cli` | GCP operations |
| `circleci/kubernetes` | K8s deploy |
| `circleci/slack` | Slack notifications |

### Orb Versioning
```yaml
# Exact version (recommended for production)
node: circleci/node@5.2.0

# Minor version (gets patches)
node: circleci/node@5.2

# Major version (gets minor and patches)
node: circleci/node@5

# Volatile (not recommended - always latest)
node: circleci/node@volatile
```

## Contexts & Secrets

### Using Contexts
```yaml
workflows:
  deploy:
    jobs:
      - deploy:
          context:
            - aws-credentials
            - slack-tokens
```

### Environment Variables Priority
1. Job-level environment
2. Context variables
3. Project settings
4. Built-in CircleCI variables

### Secrets Best Practices
```yaml
# Don't echo secrets
- run:
    name: Deploy
    command: |
      set +x  # Disable command echo
      ./deploy.sh

# Use write_to_file for sensitive data
- run:
    name: Setup credentials
    command: |
      echo "$GCP_SERVICE_KEY" > /tmp/gcp-key.json
      gcloud auth activate-service-account --key-file=/tmp/gcp-key.json
      rm /tmp/gcp-key.json
```

## Resource Classes

### Available Classes (Docker)
| Class | vCPUs | RAM | Cost |
|-------|-------|-----|------|
| `small` | 1 | 2GB | 5 credits/min |
| `medium` | 2 | 4GB | 10 credits/min |
| `medium+` | 3 | 6GB | 15 credits/min |
| `large` | 4 | 8GB | 20 credits/min |
| `xlarge` | 8 | 16GB | 40 credits/min |
| `2xlarge` | 16 | 32GB | 80 credits/min |

### Machine Executors
```yaml
jobs:
  docker-build:
    machine:
      image: ubuntu-2204:current
      docker_layer_caching: true  # Speed up Docker builds
    resource_class: large
    steps:
      - checkout
      - run: docker build -t myapp .
```

## Workflow Patterns

### Sequential Jobs
```yaml
workflows:
  main:
    jobs:
      - build
      - test:
          requires:
            - build
      - deploy:
          requires:
            - test
```

### Parallel Jobs
```yaml
workflows:
  main:
    jobs:
      - build
      - lint  # Runs in parallel with build
      - unit-tests:
          requires:
            - build
      - integration-tests:
          requires:
            - build
      # Both test jobs run in parallel
      - deploy:
          requires:
            - unit-tests
            - integration-tests
```

### Branch Filtering
```yaml
workflows:
  main:
    jobs:
      - build:
          filters:
            branches:
              only:
                - main
                - /feature\/.*/
              ignore:
                - /wip-.*/
```

### Manual Approval
```yaml
workflows:
  deploy:
    jobs:
      - build
      - hold-for-approval:
          type: approval
          requires:
            - build
      - deploy-prod:
          requires:
            - hold-for-approval
```

### Scheduled Workflows
```yaml
workflows:
  nightly:
    triggers:
      - schedule:
          cron: "0 2 * * *"  # 2 AM UTC daily
          filters:
            branches:
              only:
                - main
    jobs:
      - full-regression-tests
```

### Matrix Jobs
```yaml
jobs:
  test:
    parameters:
      node-version:
        type: string
    docker:
      - image: cimg/node:<< parameters.node-version >>
    steps:
      - checkout
      - run: npm test

workflows:
  test-matrix:
    jobs:
      - test:
          matrix:
            parameters:
              node-version: ["18.19", "20.10", "21.5"]
```
