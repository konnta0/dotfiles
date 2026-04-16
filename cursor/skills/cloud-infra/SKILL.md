---
name: cloud-infra
description: AWS and Google Cloud infrastructure patterns covering IAM least-privilege, VPC design, secrets management, CDK/Terraform choice, and security best practices. Use when working on AWS or GCP infrastructure, cloud architecture, IAM policies, networking, or security configuration.
---

# Cloud Infrastructure (AWS / GCP)

## Common principles

- **Least privilege**: Grant only the permissions a workload actually needs. Start minimal and expand only when required.
- **No hardcoded credentials**: Use IAM roles (AWS) or service accounts with Workload Identity (GCP). Never put access keys in code, environment files, or Terraform.
- **Encrypt at rest and in transit**: Enable default encryption on all storage services; enforce TLS on all endpoints.
- **Audit logging**: Enable CloudTrail (AWS) or Cloud Audit Logs (GCP) in all regions/projects.

---

## AWS

### IAM

```hcl
# Restrict to specific actions and resources; avoid wildcards
resource "aws_iam_policy" "app" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.data.arn}/*"
    }]
  })
}
```

- Prefer IAM roles attached to EC2/ECS/Lambda over long-lived access keys.
- Use permission boundaries on roles created by automation.
- Rotate and audit access keys; enforce MFA for human users.

### VPC

- Separate public (NAT gateway) and private subnets across ≥ 2 AZs.
- Keep application compute (EC2, ECS, Lambda) in private subnets.
- Use VPC Endpoints for S3 and DynamoDB to avoid NAT traffic costs.
- Restrict Security Groups to known CIDRs / source SGs; never open `0.0.0.0/0` inbound except for ALB port 443.

### Secrets

- Store secrets in AWS Secrets Manager (rotation supported) or SSM Parameter Store (SecureString).
- Never pass secrets as plain environment variables or Terraform variables without `sensitive = true`.

### Tooling choice

| Use case | Recommended |
|---|---|
| AWS-native IaC with type safety | CDK (TypeScript / C#) |
| Multi-cloud or existing Terraform state | Terraform AWS provider |
| Ad-hoc resource inspection | AWS CLI / `awscli` |

---

## Google Cloud

### IAM / Service Accounts

```hcl
resource "google_service_account" "app" {
  account_id   = "app-sa"
  display_name = "Application service account"
}

resource "google_project_iam_member" "app_storage" {
  project = var.project_id
  role    = "roles/storage.objectUser"
  member  = "serviceAccount:${google_service_account.app.email}"
}
```

- One service account per workload; never share across unrelated services.
- Use Workload Identity Federation for CI/CD (GitHub Actions, Cloud Build) instead of JSON key files.
- Prefer predefined roles; use custom roles only when predefined roles are too broad.

### VPC / Networking

- Use Shared VPC for multi-project environments; keep network management centralized.
- Cloud Run and GKE workloads: restrict egress with VPC connector + firewall rules.
- Enable Private Google Access on subnets so VMs reach Google APIs without public IPs.

### Secrets

- Use Secret Manager; grant `roles/secretmanager.secretAccessor` to the consuming service account only.

### Project structure

- One GCP project per environment (dev / stg / prd) per application domain.
- Use labels consistently: `env`, `team`, `app`.

---

## Security review checklist

- [ ] No wildcard `*` in IAM actions or resources without explicit justification
- [ ] No public-facing storage buckets (S3 Block Public Access / GCS uniform bucket-level access)
- [ ] Secrets in managed secret stores, not in code or plain env vars
- [ ] Network access restricted to necessary sources only
- [ ] Audit logging enabled
- [ ] Encryption at rest enabled on all storage resources
