locals {
  # This is true when we enable other resources that need
  # the public-facing load balancer to be provisioned.
  public_http_https_load_balancer_enabled = (
    length(local.containers_with_public_https) > 0
  )
}

# TODO: Should we expose the log bucket as an output?
module "public_http_https__log" {
  providers = {
    aws = aws
  }
  source = "./modules/load_balancer_s3_log_buckets"
  names  = ["${var.provose_config.name}-p.${var.provose_config.internal_subdomain}.${var.provose_config.internal_root_domain}"]
}

resource "aws_security_group" "public_http_https" {
  count                  = local.public_http_https_load_balancer_enabled ? 1 : 0
  name                   = "P/v1/${var.provose_config.name}/public_http_https"
  description            = "Provose security group owned by module ${var.provose_config.name} to give HTTP and HTTPS access to the public Internet."
  vpc_id                 = aws_vpc.vpc.id
  revoke_rules_on_delete = true
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_lb" "public_http_https" {
  #  count              = local.public_http_https_load_balancer_enabled ? 1 : 0
  for_each = {
    for key in range(local.public_http_https_load_balancer_enabled ? 1 : 0) :
    key => key
  }
  name_prefix        = "https"
  internal           = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.public_http_https[0].id
  ]
  subnets    = aws_subnet.vpc[*].id
  depends_on = [aws_internet_gateway.vpc]
  access_logs {
    bucket  = module.public_http_https__log.buckets["${var.provose_config.name}-p.${var.provose_config.internal_subdomain}.${var.provose_config.internal_root_domain}"].id
    prefix  = "${var.provose_config.name}-public-http-https-logs"
    enabled = true
  }
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_lb_listener" "public_http_https__443" {
  #  count             = local.public_http_https_load_balancer_enabled ? 1 : 0
  #  count             = length(aws_lb.public_http_https)
  for_each          = aws_lb.public_http_https
  load_balancer_arn = aws_lb.public_http_https[each.key].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  # The default certificate is the one we use for internal requests.
  # Every container needs to attach a separate certificate for its own
  # attachments.
  certificate_arn = aws_acm_certificate_validation.internal_dns.certificate_arn
  # By default, we return a 404.
  # Every container needs to attach a rule that defines a not-404 destination.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not found lol"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener" "public_http_https__80" {
  #  count             = local.public_http_https_load_balancer_enabled ? 1 : 0
  #  count             = length(aws_lb.public_http_https)
  for_each          = aws_lb.public_http_https
  load_balancer_arn = aws_lb.public_http_https[each.key].arn
  port              = 80
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

output "public_http_https" {
  value = {
    aws_security_group = {
      public_http_https = try(aws_security_group.public_http_https[0], null)
    }
    aws_lb = {
      public_http_https = try(aws_lb.public_http_https[0], null)
    }
    aws_lb_listener = {
      public_http_https__443 = try(aws_lb_listener.public_http_https__443[0], null)
      public_http_https__80  = try(aws_lb_listener.public_http_https__80[0], null)
    }
  }
}
