data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}


data "aws_ami" "amazon_linux_2_ecs_gpu_hvm_ebs" {
  owners = ["amazon"]
  # We make the assumption that we don't use ARM or 32-bit instances.
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-gpu-hvm-2.0.20200218-x86_64-ebs"]
  }
}

locals {
  minimum_aws_ami_root_volume_size_gb = [
    for volume in
    data.aws_ami.amazon_linux_2_ecs_gpu_hvm_ebs.block_device_mappings :
    volume.ebs.volume_size
    if volume.device_name == "/dev/xvda"
  ][0]
}


# == Output ==

output "data" {
  value = {
    aws_region = {
      current = data.aws_region.current
    }
    aws_availability_zones = {
      available = data.aws_availability_zones.available
    }
    aws_caller_identity = {
      current = data.aws_caller_identity.current
    }
    aws_ami = {
      amazon_linux_2_ecs_gpu_hvm_ebs = data.aws_ami.amazon_linux_2_ecs_gpu_hvm_ebs
    }
  }
}
