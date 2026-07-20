# AliCloud Patterns & Knowledge

## Table of Contents
- [Core Concepts](#core-concepts)
- [RAM (IAM & Security)](#ram-iam--security)
- [SDK Patterns (Go/Python)](#sdk-patterns)
- [Gotchas & Rate Limits](#gotchas--rate-limits)

## Core Concepts

### Resource Model
Resources are uniquely identified by **Alibaba Cloud Resource Names (ARN)**:
```
acs:<service>:<region>:<account-id>:<resource-type>/<resource-id>
acs:ecs:eu-west-1:123456789:instance/i-abc123
```

### Resource Directory Structure
```
Resource Directory (Master Account)
  └── Folder
        └── Member Account
```

### Regions & China Cross-Border Connectivity Gotcha
- **Standard Regions:** London (`eu-west-1`), Frankfurt (`eu-central-1`), Singapore (`ap-southeast-1`).
- **China Mainland Regions (`cn-*`):** Require separate account registration, ICP filing for web endpoints, and specialized cross-border network routing (Enterprise Project Network / CEN).

## RAM (IAM & Security)

### Policy Syntax
AWS-style JSON policy evaluation:
```json
{
  "Version": "1",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["ecs:Describe*", "ecs:List*"],
    "Resource": "*",
    "Condition": {
      "StringEquals": { "acs:SourceVpc": "vpc-xxx" }
    }
  }]
}
```

### Principal Types & Service-Linked Roles
| Principal | Format | Use Case |
|-----------|--------|----------|
| RAM User | User in account | Human / service access |
| RAM Role | Assumable identity | Cross-account / application federation |
| Service Role | `servicename.aliyuncs.com` | AliCloud system operations |

## SDK Patterns

### Go SDK (alibaba-cloud-sdk-go)
```go
import (
    "github.com/aliyun/alibaba-cloud-sdk-go/services/ecs"
)

client, _ := ecs.NewClientWithAccessKey("eu-west-1", accessKeyID, accessKeySecret)

// STS AssumeRole setup
client, _ := ecs.NewClientWithRamRoleArn("eu-west-1", accessKeyID, accessKeySecret, roleArn, roleSessionName)
```

## Gotchas & Rate Limits

| Issue | Cause | Remediation |
|-------|-------|-------------|
| `Forbidden.RAM` | Missing RAM action permission | Audit RAM policy statement actions. |
| Cross-border API Latency / Drop | China-to-Overseas API requests hitting GFW | Use Cloud Enterprise Network (CEN) or regional endpoints. |
| ECS API Throttling (`HTTP 403`) | Exceeded Describe* quota (~100 req/sec) | Implement `x-acs-request-id` exponential backoff. |
