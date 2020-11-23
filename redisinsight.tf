resource "aws_instance" "redisinsight" {
  count = var.redisinsight != null ? 1 : 0

  key_name      = try(var.redisinsight.key_name, null)
  ami           = data.aws_ami.amazon_linux_2_ecs_gpu_hvm_ebs.id
  subnet_id     = aws_subnet.vpc[0].id
  instance_type = var.redisinsight.instance_type
  vpc_security_group_ids = [
    aws_security_group.vpc_http_https[0].id,
    aws_security_group.allow_all_egress_to_internet__new.id,
    aws_security_group.vpc_ssh.id
  ]
  tags = {
    Name    = "redisinsight"
    Provose = var.provose_config.name
  }
  user_data = <<USER_DATA
#!/bin/bash
yum update -y
amazon-linux-extras install docker
systemctl start docker.service
usermod -a -G docker ec2-user
chkconfig docker on

cat > /etc/systemd/system/redisinsight.service <<-TEMPLATE
[Unit]
Description="Collects logs and sends them to Elasticsearch"
After=network.target network-online.target
Wants=network-online.target


[Service]
Type=simple
User=ec2-user
ExecStart=/usr/bin/docker run -p 80:8001 redislabs/redisinsight:${try(var.redisinsight.engine_version, "latest")}
Restart=on-failure

[Install]
WantedBy=multi-user.target
TEMPLATE
# Start the service.
systemctl start redisinsight

USER_DATA

  lifecycle {
    ignore_changes = [
      # Amazon SSM Agent sometimes changes the instance profile.
      iam_instance_profile,
    ]
  }

}

resource "aws_lb_target_group_attachment" "redisinsight" {
  count            = var.redisinsight != null ? 1 : 0
  target_group_arn = aws_lb_target_group.redisinsight[0].arn
  target_id        = aws_instance.redisinsight[0].id
}

# Terraform has an issue where it cannot replace load balancer target groups
# with another load balancer target group having the same name.
# So whenever we change a field that forces us to create a new group, we
# generate a new random name.
resource "random_id" "redisinsight" {
  count       = var.redisinsight != null ? 1 : 0
  byte_length = 20
  keepers = {
    vpc_id = aws_vpc.vpc.id
  }
}

resource "aws_lb_target_group" "redisinsight" {
  count    = var.redisinsight != null ? 1 : 0
  name     = "tg-${replace(random_id.redisinsight[0].b64_url, "_", "-")}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb_listener_rule" "redisinsight" {
  count        = var.redisinsight != null ? 1 : 0
  listener_arn = aws_lb_listener.vpc_http_https__port_443[0].arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.redisinsight[0].arn
  }

  condition {
    host_header {
      values = ["redisinsight.${local.internal_fqdn}"]
    }
  }
}

resource "aws_route53_record" "redisinsight" {
  count   = var.redisinsight != null ? 1 : 0
  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "redisinsight.${var.provose_config.internal_subdomain}"
  type    = "A"
  alias {
    name                   = aws_lb.vpc_http_https[0].dns_name
    zone_id                = aws_lb.vpc_http_https[0].zone_id
    evaluate_target_health = false
  }
}

# == Output ==

output "redisinsight" {
  value = {
    aws_instance = {
      redisinsight = aws_instance.redisinsight
    }
    aws_lb_target_group_attachment = {
      redisinsight = aws_lb_target_group_attachment.redisinsight
    }
    aws_lb_target_group = {
      redisinsight = aws_lb_target_group.redisinsight
    }
    aws_lb_listener_rule = {
      redisinsight = aws_lb_listener_rule.redisinsight
    }
    aws_route53_record = {
      redisinsight = aws_route53_record.redisinsight
    }
  }
}
