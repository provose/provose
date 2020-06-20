locals {
  aws_on_demand_instances = {
    for name, instance in var.instances :
    name => instance
    if instance.purchasing_option == "ON_DEMAND"
  }
  aws_spot_instances = {
    for name, instance in var.instances :
    name => instance
    if instance.purchasing_option == "SPOT"
  }
  minimum_root_volume_size_gb = [
    for volume in
    data.aws_ami.main.block_device_mappings :
    volume.ebs.volume_size
    if volume.device_name == "/dev/xvda"
  ][0]
  aws_on_demand_instance_ebs_volume_attachments = zipmap(
    flatten([
      for instance_name, instance in local.aws_on_demand_instances : [
        for ebs_volume_name, ebs_volume in try(instance.ebs_volumes, {}) :
        "${instance_name}-${ebs_volume_name}"
      ]
    ]),
    flatten([
      for instance_name, instance in local.aws_on_demand_instances : [
        for ebs_volume_name, ebs_volume in try(instance.ebs_volumes, {}) :
        {
          device_name   = ebs_volume.device_name
          volume_id     = ebs_volume.volume_id
          instance_name = instance_name
        }
      ]
    ])
  )
  aws_spot_instance_ebs_volume_attachments = zipmap(
    flatten([
      for instance_name, instance in local.aws_spot_instances : [
        for ebs_volume_name, ebs_volume in try(instance.ebs_volumes, {}) :
        "${instance_name}-${ebs_volume_name}"
      ]
    ]),
    flatten([
      for instance_name, instance in local.aws_spot_instances : [
        for ebs_volume_name, ebs_volume in try(instance.ebs_volumes, {}) :
        {
          device_name   = ebs_volume.device_name
          volume_id     = ebs_volume.volume_id
          instance_name = instance_name
        }
      ]
    ])
  )
}

terraform {
  required_providers {
    aws = ">= 2.54.0"
  }
}

data "aws_internet_gateway" "main__ondemand" {
  for_each            = local.aws_on_demand_instances
  internet_gateway_id = each.value.internet_gateway_id
}

data "aws_internet_gateway" "main__spot" {
  for_each            = local.aws_spot_instances
  internet_gateway_id = each.value.internet_gateway_id
}

data "aws_ami" "main" {
  owners = ["826470379119"]
  # We make the assumption that we don't use ARM or 32-bit instances.

  filter {
    name = "name"
    # If we ever change this, we'll end up forcing the deletion and recreation of
    # a lot of instances, lol.
    values = ["provose-docker-amazon-linux-2--v0.1"]
  }
}

resource "aws_volume_attachment" "main__ondemand" {
  for_each    = local.aws_on_demand_instance_ebs_volume_attachments
  device_name = each.value.device_name
  volume_id   = each.value.volume_id
  instance_id = aws_instance.main[each.value.instance_name].id
}

resource "aws_volume_attachment" "main__spot" {
  for_each    = local.aws_spot_instance_ebs_volume_attachments
  device_name = each.value.device_name
  volume_id   = each.value.volume_id
  instance_id = aws_spot_instance_request.main[each.value.instance_name].id
}

resource "aws_instance" "main" {
  for_each = local.aws_on_demand_instances
  depends_on = [
    data.aws_internet_gateway.main__ondemand
  ]

  ami               = try(each.value.ami, data.aws_ami.main.id)
  availability_zone = each.value.availability_zone
  ebs_optimized     = true # do we need to set this?
  key_name          = try(each.value.key_name, null)
  # Our user_data script won't succeed in updating yum if we don't give permissions to make
  # outbound network connections.
  vpc_security_group_ids      = each.value.vpc_security_group_ids
  instance_type               = each.value.instance_type
  subnet_id                   = each.value.subnet_id
  associate_public_ip_address = try(each.value.associate_public_ip_address, true)
  private_ip                  = try(each.value.private_ip, null)
  iam_instance_profile        = try(each.value.iam_instance_profile, null)
  root_block_device {
    volume_type = try(each.value.root_block_device.volume_type, null)
    volume_size = max(
      try(each.value.root_block_device.volume_size_gb, 0),
      local.minimum_root_volume_size_gb
    )
    delete_on_termination = try(each.value.root_block_device.delete_on_termination, true)
    encrypted             = try(each.value.root_block_device.encrypted, false)
    kms_key_id            = try(each.value.root_block_device.kms_key_id, null)
  }

  tags = each.value.tags
  user_data = templatefile(
    "${path.module}/templates/user_data_bash_script.sh",
    {
      ecs_cluster    = try(each.value.ecs_cluster, null),
      bash_user_data = try(each.value.bash_user_data, "")
    }
  )
}

resource "aws_spot_instance_request" "main" {
  for_each = local.aws_spot_instances
  depends_on = [
    data.aws_internet_gateway.main__spot
  ]
  # Below are params SPECIFIC to spot instances
  wait_for_fulfillment = true
  spot_price           = try(each.value.spot_instance.spot_price, null)

  # Below are parameters in COMMON with aws_instance, copied and pasted from above.
  ami               = try(each.value.ami, data.aws_ami.main.id)
  availability_zone = each.value.availability_zone
  ebs_optimized     = true # do we need to set this?
  key_name          = try(each.value.key_name, null)
  # Our user_data script won't succeed in updating yum if we don't give permissions to make
  # outbound network connections.
  vpc_security_group_ids      = each.value.vpc_security_group_ids
  instance_type               = each.value.instance_type
  subnet_id                   = each.value.subnet_id
  associate_public_ip_address = try(each.value.associate_public_ip_address, true)
  private_ip                  = try(each.value.private_ip, null)
  iam_instance_profile        = try(each.value.iam_instance_profile, null)
  root_block_device {
    volume_type = try(each.value.root_block_device.volume_type, null)
    volume_size = max(
      try(each.value.root_block_device.volume_size_gb, 0),
      local.minimum_root_volume_size_gb
    )
    delete_on_termination = try(each.value.root_block_device.delete_on_termination, true)
    encrypted             = try(each.value.root_block_device.encrypted, false)
    kms_key_id            = try(each.value.root_block_device.kms_key_id, null)
  }

  tags = each.value.tags
  user_data = templatefile(
    "${path.module}/templates/user_data_bash_script.sh",
    {
      ecs_cluster    = try(each.value.ecs_cluster, null),
      bash_user_data = try(each.value.bash_user_data, "")
    }
  )
}
