locals {
  elasticsearch_availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    min(length(data.aws_availability_zones.available.names), 3)
  )
  elasticsearch_subnet_ids = [
    for subnet in aws_subnet.vpc :
    subnet.id if contains(local.elasticsearch_availability_zones, subnet.availability_zone)
  ]
}

resource "aws_security_group" "elasticsearch" {
  count       = length(var.elasticsearch) > 0 ? 1 : 0
  name_prefix = "elasticsearch"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  tags = {
    Provose = var.name
  }
}

resource "aws_iam_service_linked_role" "elasticsearch" {
  count            = length(var.elasticsearch) > 0 ? 1 : 0
  aws_service_name = "es.amazonaws.com"
}

resource "aws_elasticsearch_domain" "elasticsearch" {
  for_each = var.elasticsearch

  domain_name           = each.key
  elasticsearch_version = each.value.engine_version

  cluster_config {
    instance_type          = each.value.instances.instance_type
    instance_count         = each.value.instances.count
    zone_awareness_enabled = each.value.instances.count > 1
    dynamic "zone_awareness_config" {
      for_each = {
        for name, elasticsearch in { (each.key) = each.value } :
        name => elasticsearch
        if elasticsearch.instances.count > 1
      }
      content {
        availability_zone_count = length(slice(
          local.elasticsearch_availability_zones,
          0,
          zone_awareness_config.value.instances.count
        ))
      }
    }
  }

  vpc_options {
    subnet_ids         = slice(local.elasticsearch_subnet_ids, 0, each.value.instances.count)
    security_group_ids = [aws_security_group.elasticsearch[0].id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = each.value.instances.storage_per_instance_gb
  }

  access_policies = <<CONFIG
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": "*",
            "Effect": "Allow",
            "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${each.key}/*"
        }
    ]
}
CONFIG
  tags = {
    Domain  = each.key
    Provose = var.name
  }

  depends_on = [
    aws_iam_service_linked_role.elasticsearch
  ]
}

resource "aws_lb_listener_rule" "elasticsearch" {
  for_each     = aws_elasticsearch_domain.elasticsearch
  listener_arn = aws_lb_listener.vpc_http_https__port_443.arn
  action {
    type = "redirect"
    redirect {
      host        = each.value.endpoint
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["${each.key}.${local.internal_fqdn}"]
    }
  }
}

resource "aws_lb_listener_rule" "es_kibana" {
  for_each     = aws_elasticsearch_domain.elasticsearch
  listener_arn = aws_lb_listener.vpc_http_https__port_443.arn
  action {
    type = "redirect"
    redirect {
      host        = each.value.endpoint
      path        = "/_plugin/kibana/app/kibana/#{path}"
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["${each.key}-kibana.${local.internal_fqdn}"]
    }
  }
}

# This a is a friendly DNS name of `<cluster>.internal.domain.com`
# that redirects to the Elasticsearch cluster endpoint.
# But some tools, like Logstash, will not follow redirects and instead
# throw an error.
resource "aws_route53_record" "elasticsearch" {
  for_each = aws_elasticsearch_domain.elasticsearch
  zone_id  = aws_route53_zone.internal_dns.zone_id
  name     = "${each.key}.${var.internal_subdomain}"
  type     = "A"
  alias {
    name                   = aws_lb.vpc_http_https.dns_name
    zone_id                = aws_lb.vpc_http_https.zone_id
    evaluate_target_health = false
  }
}


# This is a friendly DNS name `<cluster_name>-kibabna.internal.domain.com`
# that redirects (not proxies) to the ugly looking Kibana URL.
# This will only work through a VPN, though.
resource "aws_route53_record" "es_kibana" {
  for_each = aws_elasticsearch_domain.elasticsearch
  zone_id  = aws_route53_zone.internal_dns.zone_id
  name     = "${each.key}-kibana.${var.internal_subdomain}"
  type     = "A"
  alias {
    name                   = aws_lb.vpc_http_https.dns_name
    zone_id                = aws_lb.vpc_http_https.zone_id
    evaluate_target_health = false
  }
}

# == Output ==

output "elasticsearch" {
  value = {
    aws_security_group = {
      elasticsearch = aws_security_group.elasticsearch
    }
    aws_iam_service_linked_role = {
      elasticsearch = aws_iam_service_linked_role.elasticsearch
    }
    aws_elasticsearch_domain = {
      elasticsearch = aws_elasticsearch_domain.elasticsearch
    }
    aws_lb_listener_rule = {
      elasticsearch = aws_lb_listener_rule.elasticsearch
      es_kibana     = aws_lb_listener_rule.es_kibana
    }
    aws_route53_record = {
      elasticsearch = aws_route53_record.elasticsearch
      es_kibana     = aws_route53_record.es_kibana
    }
  }
}
