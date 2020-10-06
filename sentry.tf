resource "aws_security_group" "sentry" {
  count                  = var.sentry != null ? 1 : 0
  vpc_id                 = aws_vpc.vpc.id
  name                   = "P/v1/${var.provose_config.name}/sentry"
  description            = "Provose security group owned by module ${var.provose_config.name}, configuring ports for our Sentry installation."
  revoke_rules_on_delete = true
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
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

resource "aws_ebs_volume" "sentry" {
  count             = var.sentry != null ? 1 : 0
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = try(var.sentry.volume_size_gb, 100)
  tags = {
    Name    = "${var.provose_config.name}-sentry-volume"
    Provose = var.provose_config.name
  }
}

locals {
  sentry__ebs_volume_device_name = "/dev/sdj"
  sentry__ebs_volume_mount_point = "/var/lib/docker"
}

resource "aws_volume_attachment" "sentry" {
  count       = var.sentry != null ? 1 : 0
  device_name = local.sentry__ebs_volume_device_name
  volume_id   = aws_ebs_volume.sentry[count.index].id
  instance_id = aws_instance.sentry["sentry"].id
}

resource "aws_instance" "sentry" {
  for_each = {
    for key in var.sentry != null ? ["sentry"] : [] :
    key => key
  }
  ami                    = data.aws_ami.amazon_linux_2_ecs_gpu_hvm_ebs.id
  availability_zone      = data.aws_availability_zones.available.names[0]
  subnet_id              = aws_subnet.vpc[0].id
  instance_type          = var.sentry.instance_type
  vpc_security_group_ids = [aws_security_group.sentry[0].id]
  key_name               = try(var.sentry.key_name, null)
  user_data              = <<USER_DATA
#!/bin/bash
set -Eeuxo pipefail


mkdir -p ${local.sentry__ebs_volume_mount_point}
if file -sL ${local.sentry__ebs_volume_device_name} | grep -q "SGI XFS filesystem data"
then
  echo "Filesystem already formatted"
else
  mkfs -t xfs ${local.sentry__ebs_volume_device_name}
fi
mount ${local.sentry__ebs_volume_device_name} ${local.sentry__ebs_volume_mount_point}
# We look up the UUID because it's more permanent designation of the filesystem.
# We write to /etc/fstab so the filesystem is mounted upon reboots.
echo "UUID=$(lsblk -n -o UUID ${local.sentry__ebs_volume_device_name})  ${local.sentry__ebs_volume_mount_point}  xfs  defaults,nofail  0  2" >> /etc/fstab


yum update -y
# amazon-linux-extras install docker
# Recent Sentry versions require a much newer version of Docker than this AMI ships with.
curl https://download.docker.com/linux/static/stable/x86_64/docker-19.03.9.tgz -o /docker.tar.gz
tar xvf /docker.tar.gz
mv /docker/* /usr/bin
rm -rf /docker.tar.gz /docker
systemctl restart docker.service
usermod -a -G docker ec2-user
chkconfig docker on


yum install -y python3-pip wget unzip
python3 -m pip install docker-compose
# For some reason, /usr/local/bin/docker-compose is not in $PATH?
ln -sv /usr/local/bin/docker-compose /usr/bin/docker-compose


mkdir -p /sentry
cd /sentry
wget https://github.com/getsentry/onpremise/archive/${var.sentry.engine_version}.zip
unzip ${var.sentry.engine_version}.zip
rm -f ${var.sentry.engine_version}.zip
cd onpremise-${var.sentry.engine_version}


# Run the installer, but don't interactively create a user.
CI=1 ./install.sh


# Create a user noninteractively.
docker-compose run web sentry createuser --email '${var.sentry.superuser.email}' --password '${var.sentry.superuser.password}' --superuser --no-input
chown -R ec2-user /sentry


cat > /etc/systemd/system/sentry.service <<-TEMPLATE
[Unit]
Description="Starts Sentry on-premise and associated services"
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/sentry/onpremise-${var.sentry.engine_version}
ExecStart=/usr/local/bin/docker-compose -f /sentry/onpremise-${var.sentry.engine_version}/docker-compose.yml up
Restart=on-failure

[Install]
WantedBy=multi-user.target
TEMPLATE
# Start the service
systemctl start sentry
echo "Setup completed"
USER_DATA

  tags = {
    Name    = "${var.provose_config.name}-sentry"
    Provose = var.provose_config.name
  }
}

resource "aws_lb_target_group_attachment" "sentry" {
  for_each         = aws_instance.sentry
  target_group_arn = aws_lb_target_group.sentry["sentry"].arn
  target_id        = each.value.id
}

# Terraform has an issue where it cannot replace load balancer target groups
# with another load balancer target group having the same name.
# So whenever we change a field that forces us to create a new group, we
# generate a new random name.
resource "random_id" "sentry" {
  for_each    = aws_instance.sentry
  byte_length = 20
  keepers = {
    vpc_id = aws_vpc.vpc.id
  }
}

resource "aws_lb_target_group" "sentry" {
  for_each = aws_instance.sentry
  name     = "tg-${replace(random_id.sentry[each.key].b64_url, "_", "-")}"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  health_check {
    path = "/auth/login/sentry/"
    port = 9000
  }
}

resource "aws_lb_listener_rule" "sentry" {
  for_each     = aws_instance.sentry
  listener_arn = aws_lb_listener.vpc_http_https__port_443[0].arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sentry[each.key].arn
  }

  condition {
    host_header {
      values = ["sentry.${local.internal_fqdn}"]
    }
  }
}

resource "aws_route53_record" "sentry" {
  for_each = aws_instance.sentry
  zone_id  = aws_route53_zone.internal_dns.id
  name     = "sentry.${var.provose_config.internal_subdomain}"
  type     = "A"
  alias {
    name                   = aws_lb.vpc_http_https[0].dns_name
    zone_id                = aws_lb.vpc_http_https[0].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "sentry__host" {
  for_each = aws_instance.sentry
  zone_id  = aws_route53_zone.internal_dns.id
  name     = "sentry-host.${var.provose_config.internal_subdomain}"
  type     = "A"
  ttl      = 60
  records  = [each.value.private_ip]
}

# == Output ==

output "sentry" {
  value = {
    aws_security_group = {
      sentry = aws_security_group.sentry
    }
    aws_instance = {
      sentry = aws_instance.sentry
    }
    aws_lb_target_group_attachment = {
      sentry = aws_lb_target_group_attachment.sentry
    }
    aws_lb_target_group = {
      sentry = aws_lb_target_group.sentry
    }
    aws_lb_listener_rule = {
      sentry = aws_lb_listener_rule.sentry
    }
    aws_route53_record = {
      sentry = aws_route53_record.sentry
    }
  }
}
