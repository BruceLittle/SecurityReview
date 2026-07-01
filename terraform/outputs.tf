output "attachments_bucket_name" {
  value = aws_s3_bucket.attachments.bucket
}

output "attachments_bucket_arn" {
  value = aws_s3_bucket.attachments.arn
}

output "app_task_role_arn" {
  value = aws_iam_role.app_task_role.arn
}

output "kms_key_arn" {
  value = aws_kms_key.attachments.arn
}
