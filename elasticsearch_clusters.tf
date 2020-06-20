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

resource "aws_security_group" "elasticsearch_clusters" {
  count                  = length(var.elasticsearch_clusters) > 0 ? 1 : 0
  name                   = "P/v1/${var.provose_config.name}/elasticsearch"
  description            = "Provose security group for Elasticsearch instances, owned by module ${var.provose_config.name}."
  vpc_id                 = aws_vpc.vpc.id
  revoke_rules_on_delete = true
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  tags = {
    Provose = var.provose_config.name
  }
}

# This creates an AWS IAM Service Linked Role named
# `AWSServiceRoleForAmazonElasticsearchService`.
# If the role already exists, this command fails and then we ignore it.
# We can only have one role with this name per AWS account, which is why
# we make the role with the AWS CLI.
# If we used the `aws_iam_service_linked_role` Terraform resource to make
# Elasticsearch clusters across two Provose modules, then it would not
# be possible to successfully run `terraform apply`.
resource "null_resource" "elasticsearch_clusters__service_linked_role" {
  count = length(var.elasticsearch_clusters) > 0 ? 1 : 0
  provisioner "local-exec" {
    command = "${local.AWS_COMMAND} iam create-service-linked-role --aws-service-name=es.amazonaws.com || true"
  }
}

resource "aws_elasticsearch_domain" "elasticsearch_clusters" {
  for_each = var.elasticsearch_clusters

  domain_name           = each.key
  elasticsearch_version = each.value.engine_version

  cluster_config {
    instance_type          = each.value.instances.instance_type
    instance_count         = each.value.instances.instance_count
    zone_awareness_enabled = each.value.instances.instance_count > 1
    dynamic "zone_awareness_config" {
      for_each = {
        for name, elasticsearch in { (each.key) = each.value } :
        name => elasticsearch
        if elasticsearch.instances.instance_count > 1
      }
      content {
        availability_zone_count = length(slice(
          local.elasticsearch_availability_zones,
          0,
          zone_awareness_config.value.instances.instance_count
        ))
      }
    }
  }

  vpc_options {
    subnet_ids         = slice(local.elasticsearch_subnet_ids, 0, each.value.instances.instance_count)
    security_group_ids = [aws_security_group.elasticsearch_clusters[0].id]
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
    Provose = var.provose_config.name
  }

  depends_on = [
    null_resource.elasticsearch_clusters__service_linked_role
  ]
}

resource "aws_lb_listener_rule" "elasticsearch_clusters" {
  for_each     = aws_elasticsearch_domain.elasticsearch_clusters
  listener_arn = aws_lb_listener.vpc_http_https__port_443[0].arn
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

resource "aws_lb_listener_rule" "elasticsearch_clusters__kibana" {
  for_each     = aws_elasticsearch_domain.elasticsearch_clusters
  listener_arn = aws_lb_listener.vpc_http_https__port_443[0].arn
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
resource "aws_route53_record" "elasticsearch_clusters" {
  for_each = aws_elasticsearch_domain.elasticsearch_clusters
  zone_id  = aws_route53_zone.internal_dns.zone_id
  name     = "${each.key}.${var.provose_config.internal_subdomain}"
  type     = "A"
  alias {
    name                   = aws_lb.vpc_http_https[0].dns_name
    zone_id                = aws_lb.vpc_http_https[0].zone_id
    evaluate_target_health = false
  }
}


# This is a friendly DNS name `<cluster_name>-kibabna.internal.domain.com`
# that redirects (not proxies) to the ugly looking Kibana URL.
# This will only work through a VPN, though.
resource "aws_route53_record" "elasticsearch_clusters__kibana" {
  for_each = aws_elasticsearch_domain.elasticsearch_clusters
  zone_id  = aws_route53_zone.internal_dns.zone_id
  name     = "${each.key}-kibana.${var.provose_config.internal_subdomain}"
  type     = "A"
  alias {
    name                   = aws_lb.vpc_http_https[0].dns_name
    zone_id                = aws_lb.vpc_http_https[0].zone_id
    evaluate_target_health = false
  }
}

# == Output ==

output "elasticsearch_clusters" {
  value = {
    aws_security_group = {
      elasticsearch_clusters = aws_security_group.elasticsearch_clusters
    }
    aws_elasticsearch_domain = {
      elasticsearch_clusters = aws_elasticsearch_domain.elasticsearch_clusters
    }
    aws_lb_listener_rule = {
      elasticsearch_clusters         = aws_lb_listener_rule.elasticsearch_clusters
      elasticsearch_clusters__kibana = aws_lb_listener_rule.elasticsearch_clusters__kibana
    }
    aws_route53_record = {
      elasticsearch_clusters         = aws_route53_record.elasticsearch_clusters
      elasticsearch_clusters__kibana = aws_route53_record.elasticsearch_clusters__kibana
    }
  }
}
