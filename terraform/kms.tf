resource "aws_kms_key" "attachments" {
  description             = "SSE-KMS key for the attachments S3 bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "attachments" {
  name          = "alias/security-review-attachments-${var.environment}"
  target_key_id = aws_kms_key.attachments.key_id
}
