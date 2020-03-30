provider "aws" {
  alias = "acm_lookup"
}

resource "aws_acm_certificate" "cert" {
  provider = aws.acm_lookup
  for_each = {
    for key, site in var.sites :
    key => site.certificate_domains
  }
  domain_name               = each.value[0]
  subject_alternative_names = slice(each.value, 1, length(each.value))
  validation_method         = "DNS"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "domains" {
  provider = aws.acm_lookup
  for_each = zipmap(
    distinct(flatten(values(local.root_domains))),
    distinct(flatten(values(local.root_domains)))
  )

  name         = "${each.value}."
  private_zone = false
}

resource "aws_route53_record" "validation" {
  provider = aws.acm_lookup
  for_each = zipmap(
    flatten([
      for name, site in var.sites : [
        for i in range(length(site.certificate_domains)) :
        "${name}.${i}"
      ]
    ]),
    flatten([
      for name, site in var.sites : [
        for i in range(length(site.certificate_domains)) :
        {
          index = i
          cert  = aws_acm_certificate.cert[name]
        }
      ]
    ])
  )

  name    = each.value.cert.domain_validation_options[each.value.index].resource_record_name
  type    = each.value.cert.domain_validation_options[each.value.index].resource_record_type
  zone_id = data.aws_route53_zone.domains[join(".", slice(split(".", each.value.cert.domain_name), max(0, length(split(".", each.value.cert.domain_name)) - 2), length(split(".", each.value.cert.domain_name))))].zone_id
  records = [each.value.cert.domain_validation_options[each.value.index].resource_record_value]
  ttl     = 60


  depends_on = [aws_acm_certificate.cert]
}

resource "aws_acm_certificate_validation" "cert" {
  provider = aws.acm_lookup

  for_each        = aws_acm_certificate.cert
  certificate_arn = each.value.arn

  validation_record_fqdns = [
    for record in aws_route53_record.validation :
    record.fqdn
    if can(index(each.value.domain_validation_options[*].domain_name,
      trimprefix(record.fqdn, join(".", [record.name, ""]))
    ))
  ]

  depends_on = [aws_acm_certificate.cert, aws_route53_record.validation]
}

