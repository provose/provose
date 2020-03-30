locals {
  iter = {
    for x in var.name_prefixes :
    x => x
  }
}
data "aws_elb_service_account" "service_account" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "this" {
  for_each      = local.iter
  bucket_prefix = "${each.value}-lb-logs"
  acl           = "log-delivery-write"
  region        = data.aws_region.current.name
}

resource "aws_s3_bucket_policy" "this" {
  for_each = local.iter

  bucket = aws_s3_bucket.this[each.key].id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_elb_service_account.service_account.arn}"
      },
      "Action": "s3:PutObject",
      "Resource": "${aws_s3_bucket.this[each.key].arn}/*"
    }
  ]
}

EOF
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.iter

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [
    aws_s3_bucket.this
  ]
}
