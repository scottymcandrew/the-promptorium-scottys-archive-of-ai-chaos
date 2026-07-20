# AWS Patterns & Knowledge

## Table of Contents
- [Core Concepts](#core-concepts)
- [IAM & Policy Evaluation](#iam--policy-evaluation)
- [SDK Patterns (Go/Python)](#sdk-patterns)
- [Organisations & SCPs](#organisations--scps)
- [Common Services & Gotchas](#common-services--gotchas)

## Core Concepts

### Resource Model
Everything is a **resource** with an **ARN** (Amazon Resource Name):
```
arn:aws:service:region:account-id:resource-type/resource-id
arn:aws:s3:::my-bucket                    # Global service (no region/account)
arn:aws:ec2:eu-west-2:123456789012:instance/i-abc123
```

### Control Plane vs Data Plane
- **Control plane:** Management operations (`CreateBucket`, `DescribeInstances`)
- **Data plane:** Content operations (`PutObject`, `GetRecords` from Kinesis/DynamoDB)

Different endpoints, rate limits, and IAM action structures apply.

## IAM & Policy Evaluation

### Policy Evaluation Logic (Strict Order)
1. **Explicit Deny:** If ANY statement matches an explicit `Deny` $\rightarrow$ **DENY** (Overrides everything).
2. **Organisational SCP:** If part of AWS Organisations and SCP denies $\rightarrow$ **DENY**.
3. **Resource Policy:** If S3/KMS/SQS resource policy allows $\rightarrow$ **ALLOW** (unless identity policy denies).
4. **Identity Policy:** If IAM Role/User policy explicitly allows $\rightarrow$ **ALLOW**.
5. **Default:** Implicit **DENY**.

### Cross-Account Access & Confused Deputy Safeguard
When granting cross-account access to external roles or third-party platforms, you **MUST** enforce `sts:ExternalId`:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::EXTERNAL_ACCOUNT_ID:root" },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": { "sts:ExternalId": "unique-tenant-uuid-1234" }
    }
  }]
}
```

### Cross-Account S3 Writes & KMS Ownership Trap
When Account A writes objects to Account B's S3 bucket:
- **Bucket Owner Full Control:** Account A must append `--acl bucket-owner-full-control` (or `s3:x-amz-acl` header) on upload, or Account B cannot read the file.
- **KMS Key Grants:** If encrypted with Account A's KMS key, Account B cannot decrypt unless explicitly added to Account A's KMS key policy.

## SDK Patterns

### Python SDK (boto3) with Adaptive Retry Configuration
```python
import boto3
from botocore.config import Config

# Enforce adaptive retries for rate-limited AWS APIs (EC2/STS/IAM)
config = Config(
    retries={'max_attempts': 10, 'mode': 'adaptive'},
    region_name='eu-west-2'
)

client = boto3.client('ec2', config=config)
```

## Gotchas & Debugging

| Issue | Cause | Fix |
|-------|-------|-----|
| `AccessDenied` on S3 Object | Bucket owner mismatch or KMS Key Policy deny | Enforce `bucket-owner-full-control` and update KMS key policy. |
| IAM propagation delay | IAM changes take 10–60 seconds globally | Implement exponential retry loops. |
| IMDSv1 Security Warning | Legacy instance metadata service exposed | Enforce IMDSv2 via `HttpTokens=required` on EC2 launch. |
