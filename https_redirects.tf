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
  for_each = {
    for key, record in aws_route53_record.https_redirects :
    key => {
      url_parts          = local.https_redirects__url_parts[key]
      status_code        = "HTTP_${try(var.https_redirects[key].status_code, 301)}"
      host_header_values = [key]
    }
    if(
      contains(keys(local.https_redirects__url_parts), key) &&
      contains(keys(var.https_redirects), key)
    )
  }
  listener_arn = aws_lb_listener.public_http_https__443[0].arn
  action {
    type = "redirect"
    redirect {
      host        = each.value.url_parts.host
      port        = each.value.url_parts.port
      path        = each.value.url_parts.path
      query       = each.value.url_parts.query
      protocol    = each.value.url_parts.protocol
      status_code = each.value.status_code
    }
  }

  condition {
    host_header {
      values = each.value.host_header_values
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