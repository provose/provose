locals {
  ec2_on_demand_instances__times_count = zipmap(
    flatten([
      for instance_name, instance_config in var.ec2_on_demand_instances : [
        # If we only have one instance, then we should name it after the
        # key that the user provided.
        # If the user is requiring that we make multiple instances, then
        # we hyphenate with the instance count.
        for i in range(try(instance_config.instances.instance_count, 1)) :
        (
          try(instance_config.instances.instance_count, 1) == 1 ?
          instance_name :
          "${instance_name}-${i}"
        )
      ]
    ]),
    flatten([
      for instance_name, instance_config in var.ec2_on_demand_instances : [
        for i in range(try(instance_config.instances.instance_count, 1)) :
        instance_config
      ]
    ])
  )
}

# This is the main security group, setting public or VPC-only
# port mappings.
resource "aws_security_group" "ec2_on_demand_instances" {
  for_each = local.ec2_on_demand_instances__times_count

  name = "P/v1/${var.provose_config.name}/${each.key}/ec2_on_demand_instances"

  description            = "Provose security group for an AWS EC2 On-Demand instance named ${each.key} in module ${var.provose_config.name}."
  vpc_id                 = aws_vpc.vpc.id
  revoke_rules_on_delete = true

  dynamic "ingress" {
    for_each = try(each.value.public.tcp, [])

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = try(each.value.public.udp, [])

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = try(each.value.vpc.tcp, [])

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [aws_vpc.vpc.cidr_block]
    }
  }

  dynamic "ingress" {
    for_each = try(each.value.vpc.udp, [])

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
    Provose = var.provose_config.name
  }

}

resource "aws_iam_role" "ec2_on_demand_instances" {
  for_each = local.ec2_on_demand_instances__times_count

  name = "P-v1---${var.provose_config.name}---ec2-o-d-${each.key}---e-t-e-r"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com",
            "ec2.amazonaws.com",
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Provose = var.provose_config.name
  }
}

# This authorizes access for this instance to various
# AWS Secrets Manager secrets.
resource "aws_iam_role_policy" "ec2_on_demand_instances__secrets" {
  for_each = {
    for key, instance in local.ec2_on_demand_instances__times_count :
    key => {
      instance = instance
      role_id  = aws_iam_role.ec2_on_demand_instances[key].id
    }
    if(
      length(try(instance.secrets, {})) > 0 &&
      contains(keys(aws_iam_role.ec2_on_demand_instances), key)
    )
  }

  name = "P-v1---${var.provose_config.name}---ec2-o-d-${each.key}---secrets"
  role = each.value.role_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        for env_var_name, secret_name in each.value.instance.secrets :
        aws_secretsmanager_secret.secrets[secret_name].arn
        if contains(aws_secretsmanager_secret.secrets, secret_name)
      ]
    }]
  })
  depends_on = [
    aws_secretsmanager_secret.secrets,
    aws_secretsmanager_secret_version.secrets
  ]
}

# Allow connecting to the instance with AWS Session Manager.
resource "aws_iam_role_policy_attachment" "ec2_on_demand_instances__ssm" {
  for_each   = aws_iam_role.ec2_on_demand_instances
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

module "aws_iam_instance_profile__ec2_on_demand_instances" {
  source      = "./modules/iam_instance_profiles"
  aws_command = local.AWS_COMMAND
  profile_configs = {
    for key, role in aws_iam_role.ec2_on_demand_instances :
    key => {
      instance_profile_name = "P-v1---${var.provose_config.name}---ec2-o-d-${key}---i-p"
      path                  = "/"
      role_name             = role.name
    }
  }
}

resource "aws_instance" "ec2_on_demand_instances" {
  for_each = {
    for key, security_group in aws_security_group.ec2_on_demand_instances :
    key => {
      security_group_id = security_group.id
      ec2               = local.ec2_on_demand_instances__times_count[key]
      subnet_id = (
        can(local.ec2_on_demand_instances__times_count[key].instances.availability_zone) ?
        local.vpc__map_availability_zone_to_subnet_id[
          local.ec2_on_demand_instances__times_count[key].instances.availability_zone
        ] : aws_subnet.vpc[0].id
      )
      default_iam_instance_profile = module.aws_iam_instance_profile__ec2_on_demand_instances.instance_profiles[key].name
    }
    if contains(keys(local.ec2_on_demand_instances__times_count), key)
  }

  # Required parameters
  ami           = each.value.ec2.instances.ami_id
  instance_type = each.value.ec2.instances.instance_type

  # Optional parameters
  key_name = try(each.value.ec2.instances.key_name, null)
  # If the user is offering their own choice of Availability Zones, then AWS requires that we also
  # specify the corresponding subnet ID. Provose sets up a VPC with a subnet for every
  # Availability Zone, so when provided with an Availability Zone, we look up the corresponding
  # subnet.
  # If the user leaves the Availability Zone blank, then we put this instance in the first
  # subnet.
  availability_zone = try(each.value.ec2.instances.availability_zone, null)
  subnet_id         = each.value.subnet_id

  associate_public_ip_address = try(each.value.ec2.associate_public_ip_address, true)
  # We created one Security Group based on the ports opened by the input keys
  # public.tcp, public.udp, vpc.tcp, vpc.udp. Then we allow the end user to specify
  # additional Security Groups that might have more granular CIDRs.
  vpc_security_group_ids = concat([each.value.security_group_id], try(each.value.ec2.vpc_security_group_ids, []))
  iam_instance_profile   = try(each.value.ec2.iam_instance_profile, each.value.default_iam_instance_profile)

  root_block_device {
    volume_size           = each.value.ec2.root_block_device.volume_size_gb
    volume_type           = try(each.value.ec2.root_block_device.volume_type, null)
    delete_on_termination = try(each.value.ec2.root_block_device.delete_on_termination, true)
    encrypted             = try(each.value.ec2.root_block_device.encrypted, false)
    kms_key_id            = try(each.value.ec2.root_block_device.kms_key_id, null)
  }

  user_data = try(each.value.ec2.instances.bash_user_data, null)

  tags = {
    Name    = each.key
    Provose = var.provose_config.name
  }

  depends_on = [
    aws_internet_gateway.vpc
  ]
}

# This is a DNS record used for routing requests internal to the VPC.
resource "aws_route53_record" "ec2_on_demand_instances" {
  for_each = aws_instance.ec2_on_demand_instances

  name    = "${each.key}.${var.provose_config.internal_subdomain}"
  zone_id = aws_route53_zone.internal_dns.zone_id
  type    = "A"
  ttl     = 60
  records = [
    each.value.private_ip
  ]
}

# == Output ==

output "ec2_on_demand_instances" {
  value = {
    aws_security_group = {
      ec2_on_demand_instances = aws_security_group.ec2_on_demand_instances
    }
    aws_iam_role = {
      ec2_on_demand_instances = aws_iam_role.ec2_on_demand_instances
    }
    aws_iam_role_policy = {
      ec2_on_demand_instances__secrets = aws_iam_role_policy.ec2_on_demand_instances__secrets
    }
    aws_iam_instance_profile = {
      ec2_on_demand_instances = module.aws_iam_instance_profile__ec2_on_demand_instances.instance_profiles
    }
    aws_instance = {
      ec2_on_demand_instances = aws_instance.ec2_on_demand_instances
    }
  }
}