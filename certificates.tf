resource "aws_acm_certificate" "certificates" {
  for_each                  = var.certificates
  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  validation_method         = "DNS"
  options {
    certificate_transparency_logging_preference = "ENABLED"
  }
  lifecycle {
    create_before_destroy = true
  }
}

module "domain_name_parser" {
  for_each = toset(flatten([
    for cert in aws_acm_certificate.certificates : [
      for dvo in cert.domain_validation_options : dvo.domain_name
    ]
  ]))
  source   = "./modules/domain-name-parser"
  dns_name = each.key
}

data "aws_route53_zone" "certificates" {
  for_each     = module.domain_name_parser
  name         = format("%s.%s", each.value.domain, each.value.suffix)
  private_zone = false
}

resource "aws_route53_record" "certificates" {
  for_each = merge([
    for cert in aws_acm_certificate.certificates : {
      for dvo in cert.domain_validation_options : dvo.domain_name => {
        name   = dvo.resource_record_name
        record = dvo.resource_record_value
        type   = dvo.resource_record_type
      }
    }
  ]...)

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.certificates[each.key].zone_id
}

resource "aws_acm_certificate_validation" "certificates" {
  for_each = {
    for cert_key, cert in aws_acm_certificate.certificates : cert_key => {
      certificate_arn = cert.arn,
      validation_record_fqdns = flatten([
        for dvo in cert.domain_validation_options : [
          aws_route53_record.certificates[dvo.domain_name].fqdn
        ]
      ])
    }
  }
  certificate_arn         = each.value.certificate_arn
  validation_record_fqdns = each.value.validation_record_fqdns

  depends_on = [
    aws_acm_certificate.certificates,
    aws_route53_record.certificates
  ]
}

output "certificates" {
  value = {
    aws_acm_certificate_validation = {
      certificates = aws_acm_certificate_validation.certificates
    }
  }
}
