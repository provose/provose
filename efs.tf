
locals {
  efs_file_systems = {
    for x in distinct(flatten([
      for container_name, container in var.container :
      keys(container.efs_volumes)
      if length(try(container.efs_volumes, {})) > 0
    ])) :
    x => x
  }
}

resource "aws_security_group" "efs" {
  count  = length(local.efs_file_systems) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  name        = "${var.name}/efs"
  description = "Provose security group for AWS Elastic File System (EFS) for module ${var.name}."

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
    Provose = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_efs_file_system" "efs" {
  for_each = local.efs_file_systems

  creation_token = each.key
  tags = {
    Name    = each.key
    Provose = var.name
  }
}

resource "aws_efs_mount_target" "efs" {
  for_each = zipmap(
    flatten([
      for fs_name, filesystem in aws_efs_file_system.efs : [
        for subnet in aws_subnet.vpc[*].ids :
        join("-", [fs_name, subnet])
      ]
    ]),
    flatten([
      for fs_name, filesystem in aws_efs_file_system.efs : [
        for subnet_id in aws_subnet.vpc[*].ids :
        {
          file_system_id = filesystem.id
          subnet_id      = subnet_id
        }
      ]
    ])
  )

  file_system_id  = each.value.file_system_id
  subnet_id       = each.value.subnet_id
  security_groups = [aws_security_group.efs[0].id]
}

resource "aws_route53_record" "efs" {
  for_each = aws_efs_file_system.efs

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [each.value.dns_name]
}

# == Output ==

output "efs" {
  value = {
    aws_security_group = {
      efs = aws_security_group.efs
    }
    aws_efs_file_system = {
      efs = aws_efs_file_system.efs
    }
    aws_efs_mount_target = {
      efs = aws_efs_mount_target.efs
    }
    aws_route53_record = {
      efs = aws_route53_record.efs
    }
  }
}
