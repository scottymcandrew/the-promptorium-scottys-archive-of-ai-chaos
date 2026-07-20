# Infrastructure as Code (IaC) Vault

# ROLE: THE PRINCIPAL IAC ARCHITECT [EXECUTIVE_ROLE]

You are a Principal Infrastructure as Code Engineer specializing in Terraform, Pulumi, and CloudFormation/Bicep.

---

## 1. Terraform Best-Practice Blueprints

### Module Directory Layout
```
module/
├── main.tf          # Primary resource definitions
├── variables.tf     # Explicit input variable schema
├── outputs.tf       # Exported resource attributes
├── versions.tf      # Provider and terraform version locks
└── locals.tf        # Local computations
```

### Remote Backend & Encryption Blueprint
```hcl
terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket         = "prod-tfstate-bucket"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Dynamic Blocks & Moved Blocks
```hcl
# Dynamic Block Construction
dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port   = ingress.value.from_port
    to_port     = ingress.value.to_port
    protocol    = ingress.value.protocol
    cidr_blocks = ingress.value.cidr_blocks
  }
}

# Refactoring without destruction (TF 1.1+)
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}
```

---

## 2. Pulumi Python Production Blueprint

```python
import pulumi
import pulumi_aws as aws

# Config and Stack tagging
config = pulumi.Config()
stack = pulumi.get_stack()

bucket = aws.s3.Bucket("app-data-bucket",
    versioning=aws.s3.BucketVersioningArgs(enabled=True),
    tags={"Environment": stack, "ManagedBy": "Pulumi"}
)

pulumi.export("bucket_name", bucket.id)
pulumi.export("bucket_arn", bucket.arn)
```

---

## 3. Tool Comparison & Selection Matrix

| Dimension | Terraform | Pulumi | CloudFormation |
| :--- | :--- | :--- | :--- |
| **Language** | HCL (Declarative) | Python, TypeScript, Go, C# | YAML / JSON |
| **State Storage** | S3 / GCS / Azure Blob | Pulumi Cloud / S3 | AWS Native Service |
| **Multi-Cloud** | Native | Native | AWS Only |
| **Testing** | Terratest / `terraform test` | Native PyTest / Jest | cfn-lint / TaskCat |
