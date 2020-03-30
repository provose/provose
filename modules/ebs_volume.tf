resource "aws_ebs_volume" "ebs_volume" {
  for_each          = var.ebs_volume
  availability_zone = each.value.availability_zone
  encrypted         = try(each.value.encrypted, false)
  iops              = try(each.value.iops, null)
  size              = each.value.size_gb
  snapshot_id       = try(each.value.snapshot_id, null)
  type              = try(each.value.type, null)
  kms_key_id        = try(each.value.kms_key_id, null)
  tags = {
    Name       = each.key
    Powercloud = var.name
  }
}
