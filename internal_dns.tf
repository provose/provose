locals {
  internal_subdomain = "internal"
  internal_fqdn      = "${var.internal_subdomain}.${var.root_domain}"
}

resource "aws_route53_zone" "internal_dns" {
  name = var.root_domain

  vpc {
    vpc_id = aws_vpc.vpc.id
  }
  tags = {
    Powercloud = var.name
  }
}

resource "aws_acm_certificate" "internal_dns" {
  domain_name       = "*.${local.internal_fqdn}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# We are using this certificate for usage internal to the VPC,
# but we need to do DNS certificate validation with the public (NOT internal)
# hosted zone.
resource "aws_route53_record" "internal_dns__validation" {
  name    = aws_acm_certificate.internal_dns.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.internal_dns.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.external_dns.id
  records = [aws_acm_certificate.internal_dns.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "internal_dns" {
  certificate_arn         = aws_acm_certificate.internal_dns.arn
  validation_record_fqdns = [aws_route53_record.internal_dns__validation.fqdn]
}

# == Output == 

output "internal_dns" {
  value = {
    aws_route53_zone = {
      internal_dns = aws_route53_zone.internal_dns
    }
    aws_acm_certificate = {
      internal_dns = aws_acm_certificate.internal_dns
    }
    aws_route53_record = {
      internal_dns__validation = aws_route53_record.internal_dns__validation
    }
    aws_acm_certificate_validation = {
      internal_dns = aws_acm_certificate_validation.internal_dns
    }
  }
}
