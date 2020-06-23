terraform {
  # Look out. We're going to replace this `backend "local"` block with
  # a `backend "s3"` block later in the tutorial.
  backend "local" {
    path = "terraform.tfstate"
  }
  required_providers {
    # Provose v1.0 currently uses the Terraform AWS provider 2.54.0.
    # Stick with this version for your own code to avoid compatibility
    # issues.
    aws = "2.54.0"
  }
}

provider "aws" {
  region = "us-east-1"
}

# This is an AWS Key Management Service (KMS) key that we will use to
# encrypt the AWS S3 bucket.
resource "aws_kms_key" "terraform" {
  description = "Used to encrypt the Terraform state S3 bucket at rest."
  tags = {
    Provose = "terraform"
  }
  lifecycle {
    prevent_destroy = true
  }
}

# This is where we store the Terraform remote tfstate.
resource "aws_s3_bucket" "terraform" {
  # This should be a globally-unique Amazon S3 bucket, although it
  # should not be accessible outside of the AWS credentials you use to run
  # Terraform.
  bucket = "terraform-state.example-internal.com"
  acl    = "private"
  region = "us-east-1"

  # For security and compliance reasons, Provose recommends that you
  # configure AWS Key Management Service (KMS) encryption at rest for
  # the bucket.
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.terraform.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  versioning {
    enabled = true
  }
  tags = {
    Provose = "terraform"
  }
  # This lifecycle parameter prevents Terraform from destroying the
  # bucket that contains its own state.
  lifecycle {
    prevent_destroy = true
  }
}

# This prevents public access to our remote Terraform tfstate.
resource "aws_s3_bucket_public_access_block" "terraform" {
  bucket = aws_s3_bucket.terraform.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  lifecycle {
    prevent_destroy = true
  }
}