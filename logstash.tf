locals {
  logstash_configs = {
    for key, val in var.elasticsearch_clusters :
    key => val.logstash
    if can(val.logstash)
  }
}

resource "aws_security_group" "logstash" {
  count                  = length(local.logstash_configs) > 0 ? 1 : 0
  vpc_id                 = aws_vpc.vpc.id
  name                   = "P/v1/${var.provose_config.name}/logstash"
  description            = "Provose security group owned by the ${var.provose_config.name}, authorizing ports for the Logstash configuration."
  revoke_rules_on_delete = true
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  ingress {
    from_port   = 5959
    to_port     = 5959
    protocol    = "udp"
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

resource "aws_instance" "logstash" {
  for_each = {
    for key, config in local.logstash_configs :
    key => {
      config   = config
      endpoint = aws_elasticsearch_domain.elasticsearch_clusters[key].endpoint
    }
    if contains(keys(aws_elasticsearch_domain.elasticsearch_clusters), key)
  }

  key_name               = try(each.value.config.key_name, null)
  ami                    = data.aws_ami.amazon_linux_2_ecs_gpu_hvm_ebs.id
  subnet_id              = aws_subnet.vpc[0].id
  vpc_security_group_ids = [aws_security_group.logstash[0].id]
  instance_type          = each.value.config.instance_type
  root_block_device {
    volume_size = max(
      try(each.value.config.root_volume_size_gb, 0),
      local.minimum_aws_ami_root_volume_size_gb
    )
  }

  tags = {
    Name    = "${each.key}-logstash"
    Provose = var.provose_config.name
  }

  user_data = <<USER_DATA
#!/bin/bash
yum update -y
amazon-linux-extras install docker
systemctl start docker.service
usermod -a -G docker ec2-user
chkconfig docker on

mkdir -p /logstash/data /logstash/pipeline
chown -R ec2-user /logstash

cat > /logstash/pipeline/main.config <<-LOGSTASH
input {
  udp {
    port => 5959
    codec => json
  }
}
output {
  elasticsearch {
    hosts => ["https://${each.value.endpoint}:443"]
    ilm_enabled => false
  }
  stdout {
    codec => rubydebug
  }
}
LOGSTASH

cat > /etc/systemd/system/logstash.service <<-TEMPLATE
[Unit]
Description="Collects logs and sends them to Elasticsearch"
After=network.target network-online.target
Wants=network-online.target


[Service]
Type=simple
User=ec2-user
ExecStart=/usr/bin/docker run -u=1000 -p 5959:5959/udp -v "/logstash/data:/usr/share/logstash/data" -v "/logstash/pipeline:/usr/share/logstash/pipeline" docker.elastic.co/logstash/logstash-oss:7.1.1
Restart=on-failure

[Install]
WantedBy=multi-user.target
TEMPLATE
# Start the service.
systemctl start logstash
USER_DATA

  lifecycle {
    ignore_changes = [
      # Amazon SSM Agent sometimes changes the instance profile.
      iam_instance_profile,
    ]
  }
}

resource "aws_route53_record" "logstash" {
  for_each = aws_instance.logstash
  zone_id  = aws_route53_zone.internal_dns.zone_id
  name     = "${each.key}-logstash.${var.provose_config.internal_subdomain}"
  type     = "A"
  ttl      = 60
  records  = [each.value.private_ip]
}

# == Output ==

output "logstash" {
  value = {
    aws_security_group = {
      logstash = aws_security_group.logstash
    }
    aws_instance = {
      logstash = aws_instance.logstash
    }
    aws_route53_record = {
      logstash = aws_route53_record.logstash
    }
  }
}
