locals {
  # This is true when we enable other resources that need
  # the VPC load balnacer to be provisioned.
  vpc_http_https_load_balancer_enabled = (
    (length(var.elasticsearch_clusters) > 0) ||
    (length(local.containers_with_vpc_https) > 0)
  )
}

resource "aws_security_group" "vpc_http_https" {
  count                  = local.vpc_http_https_load_balancer_enabled ? 1 : 0
  name                   = "P/v1/${var.provose_config.name}/vpc_http_https"
  vpc_id                 = aws_vpc.vpc.id
  description            = "Provose security group owned by module ${var.provose_config.name}, allowing HTTP and HTTPS access, but only from within the VPC."
  revoke_rules_on_delete = true
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

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

resource "aws_lb" "vpc_http_https" {
  count    = local.vpc_http_https_load_balancer_enabled ? 1 : 0
  internal = true
  security_groups = [
    aws_security_group.vpc_http_https[0].id,
    aws_security_group.allow_all_egress_to_internet__new.id
  ]
  load_balancer_type = "application"
  subnets            = aws_subnet.vpc[*].id
  depends_on         = [aws_internet_gateway.vpc]
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_lb_listener" "vpc_http_https__port_443" {
  count             = local.vpc_http_https_load_balancer_enabled ? 1 : 0
  load_balancer_arn = aws_lb.vpc_http_https[0].arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.internal_dns.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not found omg"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener" "vpc_http_https__port_80" {
  count             = local.vpc_http_https_load_balancer_enabled ? 1 : 0
  load_balancer_arn = aws_lb.vpc_http_https[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# == Output ==

output "vpc_http_https" {
  value = {
    aws_security_group = {
      vpc_http_https = try(aws_security_group.vpc_http_https[0], null)
    }
    aws_lb = {
      vpc_http_https = try(aws_lb.vpc_http_https[0], null)
    }
    aws_lb_listener = {
      vpc_http_https__port_443 = try(aws_lb_listener.vpc_http_https__port_443[0], null)
      vpc_http_https__port_80  = try(aws_lb_listener.vpc_http_https__port_80[0], null)
    }
  }
}
