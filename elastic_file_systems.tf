resource "aws_security_group" "elastic_file_systems" {
  count  = length(var.elastic_file_systems) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  name                   = "P/v1/${var.provose_config.name}/efs"
  description            = "Provose security group for module ${var.provose_config.name} Elastic File System"
  revoke_rules_on_delete = true
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_efs_file_system" "elastic_file_systems" {
  for_each = var.elastic_file_systems

  creation_token = each.key
  tags = {
    Name    = each.key
    Provose = var.provose_config.name
  }
}

resource "aws_efs_mount_target" "elastic_file_systems" {
  for_each = zipmap(
    flatten([
      for file_system_key, file_system in var.elastic_file_systems : [
        for availability_zone_name in data.aws_availability_zones.available.names :
        join("-", [file_system_key, availability_zone_name])
      ]
    ]),
    flatten([
      for file_system_key, file_system in var.elastic_file_systems : [
        for subnet_index in range(length(data.aws_availability_zones.available.names)) :
        {
          file_system_key = file_system_key
          subnet_index    = subnet_index
        }
      ]
    ])
  )
  file_system_id  = aws_efs_file_system.elastic_file_systems[each.value.file_system_key].id
  subnet_id       = aws_subnet.vpc[each.value.subnet_index].id
  security_groups = [aws_security_group.elastic_file_systems[0].id]

  depends_on = [
    aws_efs_file_system.elastic_file_systems,
    aws_subnet.vpc,
  ]
}

resource "aws_route53_record" "elastic_file_systems" {
  for_each = aws_efs_file_system.elastic_file_systems

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.provose_config.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [each.value.dns_name]
}

# == Output ==

output "elastic_file_systems" {
  value = {
    aws_security_group = {
      elastic_file_systems = aws_security_group.elastic_file_systems
    }
    aws_efs_file_system = {
      elastic_file_systems = aws_efs_file_system.elastic_file_systems
    }
    aws_efs_mount_target = {
      elastic_file_systems = aws_efs_mount_target.elastic_file_systems
    }
    aws_route53_record = {
      elastic_file_systems = aws_route53_record.elastic_file_systems
    }
  }
}
