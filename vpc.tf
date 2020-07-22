resource "aws_vpc" "vpc" {
  cidr_block           = try(var.provose_config.vpc_cidr, "10.0.0.0/16")
  enable_dns_hostnames = true
  tags = {
    Name    = var.provose_config.name
    Provose = var.provose_config.name
  }
}

resource "aws_internet_gateway" "vpc" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name    = var.provose_config.name
    Provose = var.provose_config.name
  }
}

resource "aws_vpc_endpoint" "vpc__s3" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  auto_accept  = true
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_route" "vpc__to_internet" {
  route_table_id         = aws_vpc.vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpc.id
}

# Make as many subnets as there are available availability zones.
resource "aws_subnet" "vpc" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 3, count.index)

  depends_on = [aws_internet_gateway.vpc]

  tags = {
    Name    = "${var.provose_config.name}-s-${count.index}"
    Provose = var.provose_config.name
  }
}

locals {
  # This is a dictionary mapping that turns Availability Zones into subnets.
  # This is necessary because--for historical reasons--we use integer indexes
  # for indexing both availability zones and subnets.
  vpc__map_availability_zone_to_subnet_id = {
    for index in range(length(data.aws_availability_zones.available.names)) :
    data.aws_availability_zones.available.names[index] => aws_subnet.vpc[index].id
    if(
      can(data.aws_availability_zones.available.names[index]) &&
      can(aws_subnet.vpc[index].id)
    )
  }
}

# == Output ==

output "vpc" {
  value = {
    aws_vpc = {
      vpc = aws_vpc.vpc
    }
    aws_internet_gateway = {
      vpc = aws_internet_gateway.vpc
    }
    aws_route = {
      vpc__to_internet = aws_route.vpc__to_internet
    }
    aws_subnet = {
      vpc = aws_subnet.vpc
    }
  }
}
