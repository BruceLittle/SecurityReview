# Least-privilege role for the running application (ECS task role / IRSA,
# depending on the compute platform — the trust policy below is written
# for ECS; swap the Principal for an EKS OIDC provider if deployed there).
# Notably absent: s3:DeleteObject, s3:PutBucketPolicy,
# s3:PutBucketAcl, iam:*, and any action against a bucket other than the
# one this app owns.
data "aws_iam_policy_document" "app_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_task_role" {
  name               = var.app_task_role_name
  assume_role_policy = data.aws_iam_policy_document.app_assume_role.json
}

data "aws_iam_policy_document" "app_s3_access" {
  statement {
    sid     = "ListOwnBucketOnly"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [aws_s3_bucket.attachments.arn]
  }

  statement {
    sid    = "ReadWriteAttachmentObjectsOnly"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.attachments.arn}/attachments/*"]
  }

  statement {
    sid    = "UseAttachmentsKmsKeyOnly"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.attachments.arn]
  }
}

resource "aws_iam_policy" "app_s3_access" {
  name   = "${var.app_task_role_name}-s3-access"
  policy = data.aws_iam_policy_document.app_s3_access.json
}

resource "aws_iam_role_policy_attachment" "app_s3_access" {
  role       = aws_iam_role.app_task_role.name
  policy_arn = aws_iam_policy.app_s3_access.arn
}
