# TODO: Should we expose the log bucket as an output?
module "public_http_https__log" {
  providers = {
    aws = aws
  }
  source        = "./modules/load_balancer_s3_log_buckets"
  name_prefixes = ["public-http-https"]
}

resource "aws_security_group" "public_http_https" {
  name_prefix = "https"
  vpc_id      = aws_vpc.vpc.id

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
    Powercloud = var.name
  }
}

resource "aws_lb" "public_http_https" {
  name_prefix        = "https"
  internal           = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.public_http_https.id
  ]
  subnets    = aws_subnet.vpc[*].id
  depends_on = [aws_internet_gateway.vpc]
  access_logs {
    bucket  = module.public_http_https__log.buckets["public-http-https"].id
    prefix  = "public-http-https"
    enabled = true
  }
  tags = {
    Powercloud = var.name
  }
}

resource "aws_lb_listener" "public_http_https__443" {
  load_balancer_arn = aws_lb.public_http_https.arn
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
  load_balancer_arn = aws_lb.public_http_https.arn
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
      public_http_https = aws_security_group.public_http_https
    }
    aws_lb = {
      public_http_https = aws_lb.public_http_https
    }
    aws_lb_listener = {
      public_http_https__443 = aws_lb_listener.public_http_https__443
      public_http_https__80  = aws_lb_listener.public_http_https__80
    }
  }
}
