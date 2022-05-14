data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}


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
  }
}
