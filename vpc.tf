resource "aws_vpc" "vpc" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name       = var.name
    Powercloud = var.name
  }
}

resource "aws_internet_gateway" "vpc" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name       = var.name
    Powercloud = var.name
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
    Name       = "${var.name}-s-${count.index}"
    Powercloud = var.name
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
