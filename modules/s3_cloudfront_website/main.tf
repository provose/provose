locals {
  root_domains = { for key, site in var.sites :
    key => distinct([
      for name in site.public_dns_names :
      join(".", slice(split(".", name), max(0, length(split(".", name)) - 2), length(split(".", name))))
  ]) }

  wildcard_domains = { for key, site in var.sites :
    key => distinct([
      for name in site.public_dns_names :
      join(".", ["*"], slice(split(".", name), max(0, length(split(".", name)) - 2), length(split(".", name))))
  ]) }
  subdomains = { for key, site in var.sites :
    key => distinct([
      for name in site.public_dns_names :
      join(".", slice(split(".", name), 0, max(0, length(split(".", name)) - 2)))
  ]) }
  record_map = zipmap(
    flatten([
      for site_name, site in var.sites : [
        for public_dns_name in site.public_dns_names :
        join("-", [
          site_name,
          data.aws_route53_zone.domains[join(".", slice(split(".", public_dns_name), max(0, length(split(".", public_dns_name)) - 2), length(split(".", public_dns_name))))].zone_id,
          join(".", slice(split(".", public_dns_name), 0, max(0, length(split(".", public_dns_name)) - 2)))
        ])

      ]
    ]),
    flatten([
      for site_name, site in var.sites : [
        for public_dns_name in site.public_dns_names : [
          {
            site_name = site_name
            zone_id   = data.aws_route53_zone.domains[join(".", slice(split(".", public_dns_name), max(0, length(split(".", public_dns_name)) - 2), length(split(".", public_dns_name))))].zone_id
            subdomain = join(".", slice(split(".", public_dns_name), 0, max(0, length(split(".", public_dns_name)) - 2)))
          }
        ]
      ]
    ])
  )
}

resource "aws_cloudfront_origin_access_identity" "this" {
  for_each = var.sites
}

resource "aws_iam_role" "cloudfront_subdirectory_index_html" {
  count = length(var.sites) > 0 ? 1 : 0
  name  = "cloudfront_subdirectory_index_html_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    },
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "edgelambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "archive_file" "cloudfront_subdirectory_index_html" {
  count       = length(var.sites) > 0 ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/lambda_functions/cloudfront_subdirectory_index_html/index.js"
  output_path = "${path.module}/build/cloudfront_subdirectory_index_html.zip"
}

resource "aws_lambda_function" "cloudfront_subdirectory_index_html" {
  count            = length(var.sites) > 0 ? 1 : 0
  function_name    = "cloudfront_subdirectory_index_html"
  role             = aws_iam_role.cloudfront_subdirectory_index_html[0].arn
  source_code_hash = data.archive_file.cloudfront_subdirectory_index_html[0].output_base64sha256
  filename         = data.archive_file.cloudfront_subdirectory_index_html[0].output_path
  handler          = "index.handler"
  runtime          = "nodejs10.x"
  publish          = true
}

resource "aws_s3_bucket" "this" {
  for_each = var.sites
  bucket   = each.value.public_dns_names[0]
  acl      = "public-read"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_cloudfront_origin_access_identity.this[each.key].iam_arn}"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::neocrym.com/*"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_cloudfront_origin_access_identity.this[each.key].iam_arn}"
            },
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::neocrym.com"
        }
    ]
}
EOF
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

module "log" {
  providers = {
    aws = aws
  }
  source        = "../load_balancer_s3_log_buckets"
  name_prefixes = keys(var.sites)
}

resource "aws_cloudfront_distribution" "this" {
  for_each = var.sites

  origin {
    domain_name = aws_s3_bucket.this[each.key].bucket_regional_domain_name
    origin_id   = "myS3Origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this[each.key].cloudfront_access_identity_path
    }
  }

  enabled         = true
  is_ipv6_enabled = true

  logging_config {
    include_cookies = false
    bucket          = module.log.buckets[each.key].bucket_domain_name
    prefix          = each.key
  }

  aliases = each.value.public_dns_names

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "myS3Origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.cloudfront_subdirectory_index_html[0].qualified_arn
      include_body = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert[each.key].arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

# From https://www.terraform.io/docs/providers/aws/r/cloudfront_origin_access_identity.html
data "aws_iam_policy_document" "s3_policy" {
  count = length(var.sites) > 0 ? 1 : 0
  statement {
    actions   = ["s3:GetObject"]
    resources = [for bucket in aws_s3_bucket.this : "${bucket.arn}/*"]

    principals {
      type = "AWS"
      identifiers = [for identity in aws_cloudfront_origin_access_identity.this :
        identity.iam_arn
      ]
    }
  }

  statement {
    actions = ["s3:ListBucket"]
    resources = [
      for bucket in aws_s3_bucket.this : bucket.arn
    ]

    principals {
      type = "AWS"
      identifiers = [for identity in aws_cloudfront_origin_access_identity.this :
        identity.iam_arn
      ]
    }
  }
}

# From https://www.terraform.io/docs/providers/aws/r/cloudfront_origin_access_identity.html
resource "aws_s3_bucket_policy" "this" {
  for_each = var.sites
  bucket   = aws_s3_bucket.this[each.key].id
  policy   = data.aws_iam_policy_document.s3_policy[0].json
}

resource "aws_route53_record" "ipv4" {
  for_each = local.record_map
  name     = each.value.subdomain
  zone_id  = each.value.zone_id
  type     = "A"
  alias {
    name                   = aws_cloudfront_distribution.this[each.value.site_name].domain_name
    zone_id                = aws_cloudfront_distribution.this[each.value.site_name].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ipv6" {
  for_each = local.record_map
  name     = each.value.subdomain
  zone_id  = each.value.zone_id
  type     = "AAAA"
  alias {
    name                   = aws_cloudfront_distribution.this[each.value.site_name].domain_name
    zone_id                = aws_cloudfront_distribution.this[each.value.site_name].hosted_zone_id
    evaluate_target_health = false
  }
}