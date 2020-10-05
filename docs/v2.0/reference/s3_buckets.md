---
title: s3_buckets
parent: Reference v2.0
grand_parent: Docs - v2.0
---

# s3_buckets

## Description

The Provose `s3_buckets` module is a mapping of S3 buckets--which must have globally unique names--and some basic settings.

## Examples

```terraform
{% include v2.0/reference/s3_buckets/main.tf %}
```

## Inputs

- `versioning` -- **Optional.** Defaults to `false`. If set to `true`, then object versioning is enabled in the S3 bucket.

- `acl` -- **Optional.** This is a field to specify a "canned ACL." The default ACL is `"private`", where the bucket owner gets full control and nobody else has access rights. Valid ACL values are `"private"`, `"public-read"`, `"public-read-write"`, `"aws-read-exec"`, `"authenticated-read"`, `"bucket-owner-read"`, `"bucket-owner-full-control"`, or `"log-delivery-write"`. The meaning of these canned ACLs can be read on [this page in the AWS documentation](https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html#canned-acl).

## Outputs

- `s3_buckets.aws_s3_bucket.s3` -- This is a mapping from bucket names to [`aws_s3_bucket` resources](https://www.terraform.io/docs/providers/aws/r/s3_bucket.html).
