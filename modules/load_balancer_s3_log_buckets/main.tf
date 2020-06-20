locals {
  iter = {
    for x in var.names :
    x => x
  }
}
data "aws_elb_service_account" "service_account" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "this" {
  for_each = local.iter
  bucket   = each.value
  acl      = "log-delivery-write"
  region   = data.aws_region.current.name
  # We let `terraform destroy` delete automatically-created S3 buckets for logs,
  # even though it is possible that many users are required to preserve their
  # logs.
  force_destroy = true
}

resource "aws_s3_bucket_policy" "this" {
  #  for_each = local.iter
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_elb_service_account.service_account.arn}"
      },
      "Action": "s3:PutObject",
      "Resource": "${each.value.arn}/*"
    }
  ]
}

EOF
  depends_on = [
    aws_s3_bucket.this
  ]
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [
    aws_s3_bucket_policy.this,
    aws_s3_bucket.this
  ]
}
