resource "aws_security_group" "statsd_graphite_grafana" {
  count                  = var.statsd_graphite_grafana != null ? 1 : 0
  vpc_id                 = aws_vpc.vpc.id
  name                   = "P/v1/${var.provose_config.name}/statsd_graphite_grafana"
  description            = "Provose security group owned by module ${var.provose_config.name}, setting up permissions for our Statsd, Graphite, and Grafana installation."
  revoke_rules_on_delete = true
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  ingress {
    from_port   = 8125
    to_port     = 8125
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_ebs_volume" "statsd_graphite_grafana" {
  count             = var.statsd_graphite_grafana != null ? 1 : 0
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = var.statsd_graphite_grafana.metrics_volume_size_gb
  tags = {
    Name    = "${var.provose_config.name}-statsd_graphite_grafana-volume"
    Provose = var.provose_config.name
  }
}

locals {
  statsd_graphite_grafana_ebs_volume_device_name = "/dev/sdj"
}

resource "aws_volume_attachment" "statsd_graphite_grafana" {
  count       = var.statsd_graphite_grafana != null ? 1 : 0
  device_name = local.statsd_graphite_grafana_ebs_volume_device_name
  volume_id   = aws_ebs_volume.statsd_graphite_grafana[count.index].id
  instance_id = aws_instance.statsd_graphite_grafana[count.index].id
}

resource "aws_instance" "statsd_graphite_grafana" {
  count                  = var.statsd_graphite_grafana != null ? 1 : 0
  ami                    = data.aws_ami.amazon_linux_2_ecs_gpu_hvm_ebs.id
  subnet_id              = aws_subnet.vpc[0].id
  instance_type          = var.statsd_graphite_grafana.instance_type
  vpc_security_group_ids = [aws_security_group.statsd_graphite_grafana[0].id]
  key_name               = try(var.statsd_graphite_grafana.key_name, null)
  /*
  root_block_device {
    volume_size = max(
      try(var.statsd_graphite_grafana.root_volume_size_gb, 0),
      local.minimum_aws_ami_root_volume_size_gb
    )
  }
  */
  user_data = <<USER_DATA
#!/bin/bash
set -Eeuxo pipefail

yum update -y
amazon-linux-extras install docker
systemctl start docker.service
usermod -a -G docker ec2-user
chkconfig docker on

yum install -y python3-pip
python3 -m pip install docker-compose

if file -sL ${local.statsd_graphite_grafana_ebs_volume_device_name} | grep -q "SGI XFS filesystem data"
then
  echo "Filesystem already formatted"
else
  mkfs -t xfs ${local.statsd_graphite_grafana_ebs_volume_device_name}
fi

# Make the mount point and subdirectories.
mkdir -p /sgg/graphite/storage /sgg/grafana/data

mount ${local.statsd_graphite_grafana_ebs_volume_device_name} /sgg
# We look up the UUID because it's more permanent designation of the filesystem.
# We write to /etc/fstab so the filesystem is mounted upon reboots.
echo "UUID=$(lsblk -n -o UUID ${local.statsd_graphite_grafana_ebs_volume_device_name})  /sgg  xfs  defaults,nofail  0  2" >> /etc/fstab

# Set up Grafana for anonymous access.
cat - > /sgg/grafana/grafana.ini <<-GRAFANA
[auth.anonymous]
# enable anonymous access
enabled = true

# specify organization name that should be used for unauthenticated users
org_name = Main Org.
org_role = Admin

[auth.basic]
enabled = false

GRAFANA

# Set up the docker-compose file
cat - > /sgg/docker-compose.yml <<-DOCKER_COMPOSE
version: "3.1"
services:
  graphite:
    image: graphiteapp/graphite-statsd:${var.statsd_graphite_grafana.graphite_statsd_version}
    restart: always
    ports:
      - "8125:8125/udp"
      - "3001:8080"
    volumes:
     - "/sgg/graphite/storage:/opt/graphite/storage"
  grafana:
    image: bitnami/grafana:${var.statsd_graphite_grafana.grafana_version}
    restart: always
    ports:
      - "80:3000"
    volumes:
      - "/sgg/grafana/data:/opt/bitnami/grafana/data"
      - "/sgg/grafana/grafana.ini:/opt/bitnami/grafana/conf/grafana.ini"
    user: "1000:1000"
DOCKER_COMPOSE
# UID and GID 1000:1000 is ec2-user. Grafana needs to run as that user or it
# cannot write to its Docker volume.

cat > /etc/systemd/system/sgg.service <<-TEMPLATE
[Unit]
Description="Runs Statsd, Graphite, and Grafana via Docker containers."
After=network.target network-online.target
Wants=network-online.target


[Service]
Type=simple
User=ec2-user
ExecStart=/usr/local/bin/docker-compose -f /sgg/docker-compose.yml up
Restart=on-failure

[Install]
WantedBy=multi-user.target
TEMPLATE

chown --recursive ec2-user /sgg
systemctl start sgg
USER_DATA
  tags = {
    Name    = "${var.provose_config.name}-statsd_graphite_grafana"
    Provose = var.provose_config.name
  }
}

resource "aws_route53_record" "statsd" {
  count = var.statsd_graphite_grafana != null ? 1 : 0

  zone_id = aws_route53_zone.internal_dns.id
  name    = "statsd.${var.provose_config.internal_subdomain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.statsd_graphite_grafana[0].private_ip]
}

resource "aws_route53_record" "graphite" {
  count = var.statsd_graphite_grafana != null ? 1 : 0

  zone_id = aws_route53_zone.internal_dns.id
  name    = "graphite.${var.provose_config.internal_subdomain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.statsd_graphite_grafana[0].private_ip]
}

resource "aws_route53_record" "grafana" {
  count = var.statsd_graphite_grafana != null ? 1 : 0

  zone_id = aws_route53_zone.internal_dns.id
  name    = "grafana.${var.provose_config.internal_subdomain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.statsd_graphite_grafana[0].private_ip]
}

# == Output ==

output "statsd_graphite_grafana" {
  value = {
    aws_security_group = {
      statsd_graphite_grafana = aws_security_group.statsd_graphite_grafana
    }
    aws_instance = {
      statsd_graphite_grafana = aws_instance.statsd_graphite_grafana
    }
    aws_route53_record = {
      statsd   = aws_route53_record.statsd
      graphite = aws_route53_record.graphite
      grafana  = aws_route53_record.grafana
    }
  }
}
