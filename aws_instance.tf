resource "aws_security_group" "aws_instance" {
  for_each    = var.aws_instance
  name_prefix = "ai"
  description = "Powercloud security group for AWS instance ${each.key}"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = try(each.value.public_tcp, [])

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = try(each.value.public_udp, [])

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = try(each.value.internal_tcp, [])

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [aws_vpc.vpc.cidr_block]
    }
  }

  dynamic "ingress" {
    for_each = try(each.value.internal_udp, [])

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = [aws_vpc.vpc.cidr_block]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Powercloud = var.name
  }
}

module "aws_instance" {
  source = "./modules/aws_instance"
  instances = zipmap(
    flatten([
      for instance_name, instance_config in var.aws_instance : [
        for i in range(try(instance_config.instances.instance_count, 1)) :
        "${instance_name}-${i}"
      ]
    ]),
    flatten([
      for instance_name, instance_config in var.aws_instance : [
        for i in range(try(instance_config.instances.instance_count, 1)) :
        {

          purchasing_option      = instance_config.purchasing_option
          availability_zone      = null
          key_name               = instance_config.instances.key_name
          subnet_id              = aws_subnet.vpc[0].id
          vpc_security_group_ids = [aws_security_group.aws_instance[instance_name].id]
          instance_type          = instance_config.instances.instance_type
          bash_user_data         = try(instance_config.bash_user_data, "")
          root_block_device = {
            volume_size_gb = try(instance_config.root_volume.size_gb, 0)
          }
          internet_gateway_id = aws_internet_gateway.vpc.id
          tags = {
            # Name the instance after the object key, except when
            # we are creating more than one instance, in which case
            # we append the index.
            Name       = try(instance_config.instances.instance_count, 1) > 1 ? "${instance_name}-${i}" : instance_name
            Powercloud = var.name
          }
        }
      ]
    ])
  )
}

# This a unique DNS record for every individual AWS instance we are creating.
resource "aws_route53_record" "aws_instance" {
  for_each = module.aws_instance.aws_instance.on_demand
  name     = "${each.key}.${var.internal_subdomain}"
  zone_id  = aws_route53_zone.internal_dns.zone_id
  type     = "A"
  ttl      = 60
  records = [
    each.value.private_ip
  ]
}

# This is a round-robin DNS record for all of the n AWS instances
# that we are creating at once.
resource "aws_route53_record" "aws_instance__group" {
  for_each = var.aws_instance
  zone_id  = aws_route53_zone.internal_dns.zone_id
  name     = "${each.key}.${var.internal_subdomain}"
  type     = "A"
  ttl      = 60
  records = [
    for instance_name, instance in merge(
      module.aws_instance.aws_instance.on_demand,
      module.aws_instance.aws_instance.spot
    ) :
    instance.private_ip
    if join("-", slice(split("-", instance_name), 0, length(split("-", instance_name)) - 1)) == each.key
  ]
}

# == Output ==

output "aws_instance" {
  value = {
    aws_security_group = {
      aws_instance = aws_security_group.aws_instance
    }
    aws_instance = {
      aws_instance = merge(
        module.aws_instance.aws_instance.on_demand,
        module.aws_instance.aws_instance.spot
      )
    }
    aws_route53_record = {
      aws_instance        = aws_route53_record.aws_instance
      aws_instance__group = aws_route53_record.aws_instance__group
    }
  }
}
