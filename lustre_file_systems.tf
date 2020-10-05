resource "aws_security_group" "lustre_file_systems" {
  count                  = length(var.lustre_file_systems) > 0 ? 1 : 0
  vpc_id                 = aws_vpc.vpc.id
  name                   = "P/v1/${var.provose_config.name}/lustre"
  description            = "Provose security group for module ${var.provose_config.name} FSx Lustre File System"
  revoke_rules_on_delete = true
  ingress {
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  ingress {
    from_port   = 1021
    to_port     = 1023
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  egress {
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  egress {
    from_port   = 1021
    to_port     = 1023
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_fsx_lustre_file_system" "lustre_file_systems" {
  for_each                    = var.lustre_file_systems
  deployment_type             = each.value.deployment_type
  storage_capacity            = each.value.storage_capacity_gb
  per_unit_storage_throughput = try(each.value.per_unit_storage_throughput_mb_per_tb, null)
  subnet_ids                  = [aws_subnet.vpc[0].id]
  security_group_ids          = [aws_security_group.lustre_file_systems[0].id]
  import_path                 = try(each.value.s3_import_path, null)
  export_path                 = try(each.value.s3_export_path, null)
  imported_file_chunk_size    = try(each.value.imported_file_chunk_size_mb, null)
  auto_import_policy          = try(each.value.auto_import_policy, "NONE")
  lifecycle {
    # Not sure if this fixes anything, but we put this here because
    # there seem to be some weirdness with Terraform tainting this
    # resource.
    # TOOD: Investigate why `aws_fsx_lustre_file_system` resources get automatically tainted.
    ignore_changes = [
      network_interface_ids
    ]
  }
  tags = {
    Name    = each.key
    Provose = var.provose_config.name
  }
}

resource "aws_route53_record" "lustre_file_systems" {
  for_each = aws_fsx_lustre_file_system.lustre_file_systems
  zone_id  = aws_route53_zone.internal_dns.zone_id
  name     = "${each.key}.${var.provose_config.internal_subdomain}"
  type     = "CNAME"
  ttl      = "5"
  records  = [each.value.dns_name]
}

# == Output ==

output "lustre_file_systems" {
  value = {
    aws_security_group = {
      lustre_file_systems = try(aws_security_group.lustre_file_systems[0], null)
    }
    aws_fsx_lustre_file_system = {
      lustre_file_systems = aws_fsx_lustre_file_system.lustre_file_systems
    }
    aws_route53_record = {
      lustre_file_systems = aws_route53_record.lustre_file_systems
    }
  }
}
