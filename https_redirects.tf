locals {
  # This is a regex that splits a URL into three named groups:
  # - protocol
  # - host
  # - path
  # - query
  https_redirects__url_regex = "(?P<protocolcontainer>(?P<protocol>\\w+):\\/\\/)?(?P<host>[^\\/:]+)(?P<portcontainer>:(?P<port>\\d+))?(?P<path>[^\\?]*)(?P<querycontainer>\\?(?P<query>.*))?"
  https_redirects__raw_url_parts = {
    for name, redirect_obj in var.https_redirects :
    name => regex(local.https_redirects__url_regex, redirect_obj.destination)
  }
  # This is a mapping between the input domain names and the URL parts broken up from
  # the above regex.
  https_redirects__url_parts = {
    for name, groups in local.https_redirects__raw_url_parts :
    name => {
      protocol = upper(groups.protocol)
      host     = groups.host
      # If the forwarding type is "EXACT_URL", all possible redirects go to the same URL.
      # IF the forwarding type is something else e.g. "DOMAIN_NAME", then we forward
      # URL paths and query strings from the input URL.
      path = (
        var.https_redirects[name].forwarding_type == "EXACT_URL" ?
        (
          (
            try(groups.path, "/") == "/" ||
            groups.path == null ||
            groups.path == ""
          ) ?
          "/" :
          groups.path
        )
        :
        "/#{path}"
      )
      query = (
        var.https_redirects[name].forwarding_type == "EXACT_URL" ?
        (
          (
            try(groups.query, "#") != "#" ||
            groups.query != null ||
            groups.query != ""
          ) ?
          "" :
          groups.query
        ) :
        "#{query}"
      )
      port = try(
        groups.port,
        upper(groups.protocol) == "HTTP" ?
        80 :
        upper(groups.protocol) == "HTTPS" ?
        443 :
        upper(groups.protocol) == "FTP" ?
        21 : null
      )
    }
  }
  # Here we extract the top level domain names from the input URLs,
  # so we can look up the appropriate AWS Route 53 Zones.
  https_redirects__root_domains = {
    for name, redirect_obj in var.https_redirects :
    name => join(
      ".",
      slice(
        split(".", name),
        max(0, length(split(".", name)) - 2),
        length(split(".", name))
      )
    )
  }
}

# This should be an already-existing AWS Route 53 zone for the domain name.
# Ideally the source of the redirection is a domain name owned by the user in their
# AWS account.
data "aws_route53_zone" "https_redirects" {
  for_each     = local.https_redirects__root_domains
  name         = each.value
  private_zone = false
}

# Tells the load balancer how to do the redirect.
resource "aws_lb_listener_rule" "https_redirects" {
  for_each     = aws_route53_record.https_redirects
  listener_arn = aws_lb_listener.public_http_https__443[0].arn
  action {
    type = "redirect"
    redirect {
      host        = local.https_redirects__url_parts[each.key].host
      port        = local.https_redirects__url_parts[each.key].port
      path        = local.https_redirects__url_parts[each.key].path
      query       = local.https_redirects__url_parts[each.key].query
      protocol    = local.https_redirects__url_parts[each.key].protocol
      status_code = "HTTP_${try(var.https_redirects[each.key].status_code, 301)}"
    }
  }

  condition {
    host_header {
      values = [each.key]
    }
  }
}

# This is the DNS record we need for the "source" domain name for the redirect.
resource "aws_route53_record" "https_redirects" {
  for_each = data.aws_route53_zone.https_redirects
  zone_id  = each.value.zone_id
  name     = each.key
  type     = "A"
  alias {
    name                   = aws_lb.public_http_https[0].dns_name
    zone_id                = aws_lb.public_http_https[0].zone_id
    evaluate_target_health = false
  }
}

# This is the TLS certificate that will be used by the load balancer while processing
# the redirect.
resource "aws_acm_certificate" "https_redirects" {
  for_each          = aws_route53_record.https_redirects
  domain_name       = each.value.name
  validation_method = "DNS"
  options {
    certificate_transparency_logging_preference = "ENABLED"
  }
  tags = {
    Provose = var.provose_config.name
  }
}

# Create DNS records that will prove to Amazon Certificate Manager (ACM) that we own
# the domain name that we are requesting certificates for.
resource "aws_route53_record" "https_redirects__https_validation" {
  for_each = {
    for key, value in aws_acm_certificate.https_redirects :
    key => {
      domain_validation_options = tolist(value.domain_validation_options)[0]
      zone_id                   = data.aws_route53_zone.https_redirects[value.domain_name].zone_id
    }
    if contains(keys(data.aws_route53_zone.https_redirects), value.domain_name)
  }

  name       = each.value.domain_validation_options.resource_record_name
  type       = each.value.domain_validation_options.resource_record_type
  zone_id    = each.value.zone_id
  records    = [each.value.domain_validation_options.resource_record_value]
  ttl        = 60
  depends_on = [aws_acm_certificate.https_redirects]
}

# This validates our TLS certificate with the validation DNS records
# we just created above.
resource "aws_acm_certificate_validation" "https_redirects__https_validation" {
  for_each = {
    for key, certificate in aws_acm_certificate.https_redirects :
    key => {
      certificate_arn = certificate.arn
      fqdn            = aws_route53_record.https_redirects__https_validation[key].fqdn
    }
    if contains(keys(aws_route53_record.https_redirects__https_validation), key)
  }
  certificate_arn         = each.value.certificate_arn
  validation_record_fqdns = [each.value.fqdn]
}

# This resource attaches our newly-created TLS certificate to our load balancer.
# If we were to omit this, the load balancer would return the default, VPC-only
# certificate that Provose provisions. When that happens, users trying to use the
# redirect would get a TLS error.
resource "aws_lb_listener_certificate" "https_redirects__https_validation" {
  # Don't provision this resource if we don't actually have a public HTTPS load balancer
  # listener.
  for_each        = length(aws_lb_listener.public_http_https__443) > 0 ? aws_acm_certificate_validation.https_redirects__https_validation : {}
  listener_arn    = aws_lb_listener.public_http_https__443[0].arn
  certificate_arn = each.value.certificate_arn

  depends_on = [
    aws_lb_listener.public_http_https__443
  ]
}
