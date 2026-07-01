# Terraform

Provisions the S3 attachment bucket, its KMS encryption key, and the
least-privilege IAM role the application assumes at runtime.

Configure the `s3` backend (bucket + DynamoDB lock table) for your account
before running this anywhere but a sandbox — it is intentionally left
unset in `versions.tf` so it can't silently target the wrong state.

```
terraform init \
  -backend-config="bucket=<your-tfstate-bucket>" \
  -backend-config="key=security-review/<environment>.tfstate" \
  -backend-config="region=<region>" \
  -backend-config="dynamodb_table=<your-lock-table>"

terraform plan \
  -var="environment=staging" \
  -var="attachments_bucket_name=<globally-unique-name>" \
  -var="cors_allowed_origins=[\"https://app.example.com\"]"
```

Nothing here grants public S3 access, hardcodes credentials, or uses a
wildcard IAM resource — see `s3.tf` / `iam.tf` for the specifics reviewed
in the security assessment.
