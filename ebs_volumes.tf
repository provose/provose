resource "aws_ebs_volume" "ebs_volumes" {
  for_each          = var.ebs_volumes
  availability_zone = each.value.availability_zone
  encrypted         = try(each.value.encrypted, false)
  iops              = try(each.value.iops, null)
  size              = each.value.size_gb
  snapshot_id       = try(each.value.snapshot_id, null)
  type              = try(each.value.type, null)
  kms_key_id        = try(each.value.kms_key_id, null)
  tags = {
    Name    = each.key
    Provose = var.provose_config.name
  }
}

output "ebs_volumes" {
  value = {
    aws_ebs_volume = {
      ebs_volumes = aws_ebs_volume.ebs_volumes
    }
  }
}