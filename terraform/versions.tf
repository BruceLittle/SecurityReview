terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Configure a real backend (S3 + DynamoDB lock table) per environment
  # before running this anywhere but a scratch/sandbox account — state is
  # deliberately not configured here so it can't be pointed at the wrong
  # account by accident.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "security-review"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
