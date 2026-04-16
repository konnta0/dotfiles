---
name: terraform-iac
description: Terraform IaC patterns for module structure, plan-before-apply workflow, state management, variable conventions, and provider pinning. Use when writing or reviewing Terraform code, .tf files, or infrastructure definitions for AWS or GCP.
---

# Terraform IaC

## Module layout

Every module (root or reusable) follows this structure:

```
module/
├── main.tf        # resources only
├── variables.tf   # all variable blocks
├── outputs.tf     # all output blocks
└── versions.tf    # terraform{} and required_providers{}
```

Large modules split `main.tf` by logical group: `network.tf`, `compute.tf`, `iam.tf`, etc.

## Plan-before-apply workflow

```bash
# Always produce a plan file; never apply speculatively
terraform init
terraform validate
terraform plan -out=tfplan
# ── review the plan ──
terraform apply tfplan
```

In CI, add `-input=false -no-color` and publish the plan as a PR comment before merging.

## Variables and outputs

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment (dev | stg | prd)."
  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "environment must be dev, stg, or prd."
  }
}

output "bucket_name" {
  description = "Name of the S3 bucket created for artifacts."
  value       = aws_s3_bucket.artifacts.bucket
}
```

- Every variable must have `type` and `description`.
- Sensitive variables use `sensitive = true`; never set a default for secrets.

## Provider and module versions

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- Pin providers to `~> MAJOR.MINOR`.
- Pin registry modules to an exact version tag; never use `latest` or a branch ref.

## Remote state

```hcl
# AWS
terraform {
  backend "s3" {
    bucket         = "my-tf-state"
    key            = "env/prd/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# GCP
terraform {
  backend "gcs" {
    bucket = "my-tf-state"
    prefix = "env/prd"
  }
}
```

- Encryption must be enabled.
- DynamoDB (AWS) or GCS object locking (GCP) for state locking.
- Never commit `terraform.tfstate`, `.terraform/`, or `*.tfvars` with secrets.

## Lifecycle and safety

```hcl
resource "aws_s3_bucket" "data" {
  lifecycle {
    prevent_destroy = true
  }
}
```

Apply `prevent_destroy = true` to stateful resources (databases, buckets with persistent data).

## Self-review checklist

- [ ] `terraform validate` passes
- [ ] `terraform plan` output reviewed — no unintended destroys
- [ ] No hardcoded account IDs, ARNs, or credentials
- [ ] Sensitive outputs marked `sensitive = true`
- [ ] State backend configured with encryption and locking
