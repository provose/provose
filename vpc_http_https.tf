resource "aws_security_group" "vpc_http_https" {
  name_prefix = "vpc_http_https"
  vpc_id      = aws_vpc.vpc.id

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
    Provose = var.name
  }
}

resource "aws_lb" "vpc_http_https" {
  internal = true
  security_groups = [
    aws_security_group.vpc_http_https.id,
    aws_security_group.allow_all_egress_to_internet.id
  ]
  load_balancer_type = "application"
  subnets            = aws_subnet.vpc[*].id
  depends_on         = [aws_internet_gateway.vpc]
  tags = {
    Provose = var.name
  }
}

resource "aws_lb_listener" "vpc_http_https__port_443" {
  load_balancer_arn = aws_lb.vpc_http_https.arn
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
  load_balancer_arn = aws_lb.vpc_http_https.arn
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
      vpc_http_https = aws_security_group.vpc_http_https
    }
    aws_lb = {
      vpc_http_https = aws_lb.vpc_http_https
    }
    aws_lb_listener = {
      vpc_http_https__port_443 = aws_lb_listener.vpc_http_https__port_443
      vpc_http_https__port_80  = aws_lb_listener.vpc_http_https__port_80
    }
  }
}
