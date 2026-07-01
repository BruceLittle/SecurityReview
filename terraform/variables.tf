variable "environment" {
  description = "Deployment environment name (staging, production, ...)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "attachments_bucket_name" {
  description = "Globally-unique S3 bucket name for attachment storage"
  type        = string
}

variable "app_task_role_name" {
  description = "Name of the IAM role assumed by the application (ECS task role / IRSA role)"
  type        = string
  default     = "security-review-app"
}

variable "log_retention_days" {
  description = "CloudWatch/S3 access-log retention in days"
  type        = number
  default     = 365
}
