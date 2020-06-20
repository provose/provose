resource "aws_security_group" "aws_instance" {
  for_each               = var.ec2_instances
  name                   = "P/v1/${var.provose_config.name}/${each.key}/aws_instance"
  description            = "Provose security group for AWS instance ${each.key} in module ${var.provose_config.name}."
  vpc_id                 = aws_vpc.vpc.id
  revoke_rules_on_delete = true
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
    Provose = var.provose_config.name
  }
}

resource "aws_iam_role" "aws_instance__default_iam" {
  name               = "P-v1---${var.provose_config.name}---default-iam-role"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
{
    "Sid": "",
    "Effect": "Allow",
    "Principal": {
    "Service": "ecs-tasks.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
},
{
    "Sid": "",
    "Effect": "Allow",
    "Principal": {
    "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"

}
]
}
EOF
  tags = {
    Provose = var.provose_config.name
  }
}

# Allow connecting to the instance with AWS Session Manager.
resource "aws_iam_role_policy_attachment" "aws_instance__default_iam__ssm" {
  role       = aws_iam_role.aws_instance__default_iam.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

module "aws_iam_instance_profile__aws_instance" {
  source      = "./modules/iam_instance_profiles"
  aws_command = local.AWS_COMMAND
  profile_configs = {
    "default" = {
      instance_profile_name = "P-v1---${var.provose_config.name}---default-i-p"
      path                  = "/"
      role_name             = aws_iam_role.aws_instance__default_iam.name
    }
  }
}

# This is a blanket policy that generally allows the pulling of private ECR
# images, the creating and joining of ECR clusters, and the creating
# and joining of CloudWatch stuff.
# TODO: Tighten this up so that containers only have the specific permissions on the instances needed.
resource "aws_iam_role_policy" "aws_instance__default_iam" {
  name = "P-v1---${var.provose_config.name}---default-r-p"
  role = aws_iam_role.aws_instance__default_iam.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:*",
        "ecs:*",
        "ecr:*"
      ],
      Resource = ["*"]
    }]
  })
}

module "aws_instance" {
  source = "./modules/aws_instance"
  instances = length(aws_subnet.vpc) < 1 ? {} : zipmap(
    flatten([
      for instance_name, instance_config in var.ec2_instances : [
        for i in range(try(instance_config.instances.instance_count, 1)) :
        "${instance_name}-${i}"
      ]
    ]),
    flatten([
      for instance_name, instance_config in var.ec2_instances : [
        for i in range(try(instance_config.instances.instance_count, 1)) :
        {

          purchasing_option      = instance_config.purchasing_option
          availability_zone      = null
          key_name               = try(instance_config.instances.key_name, null)
          subnet_id              = aws_subnet.vpc[0].id
          vpc_security_group_ids = [try(aws_security_group.aws_instance[instance_name].id, null)]
          instance_type          = instance_config.instances.instance_type
          iam_instance_profile   = try(instance_config.iam_instance_profile, module.aws_iam_instance_profile__aws_instance.instance_profiles["default"].name)
          bash_user_data         = try(instance_config.instances.bash_user_data, "")
          root_block_device = {
            volume_size_gb = try(instance_config.root_volume.size_gb, 0)
          }
          internet_gateway_id = aws_internet_gateway.vpc.id
          tags = {
            # Name the instance after the object key, except when
            # we are creating more than one instance, in which case
            # we append the index.
            Name    = try(instance_config.instances.instance_count, 1) > 1 ? "${instance_name}-${i}" : instance_name
            Provose = var.provose_config.name
          }
        }
        if can(aws_security_group.aws_instance[instance_name])
      ]
    ])
  )
}

# This a unique DNS record for every individual AWS instance we are creating.
resource "aws_route53_record" "aws_instance__on_demand" {
  for_each = module.aws_instance.aws_instance.on_demand
  name     = "${each.key}.${var.provose_config.internal_subdomain}"
  zone_id  = aws_route53_zone.internal_dns.zone_id
  type     = "A"
  ttl      = 60
  records = [
    each.value.private_ip
  ]
}

# This a unique DNS record for every individual AWS instance we are creating.
resource "aws_route53_record" "aws_instance__spot" {
  for_each = module.aws_instance.aws_instance.spot
  name     = "${each.key}.${var.provose_config.internal_subdomain}"
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
  for_each = var.ec2_instances
  zone_id  = aws_route53_zone.internal_dns.zone_id
  name     = "${each.key}.${var.provose_config.internal_subdomain}"
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

output "ec2_instances" {
  value = {
    aws_security_group = {
      ec2_instances = aws_security_group.aws_instance
    }
    aws_instance = {
      on_demand = module.aws_instance.aws_instance.on_demand
      spot      = module.aws_instance.aws_instance.spot
    }
    aws_route53_record = {
      on_demand = aws_route53_record.aws_instance__on_demand
      spot      = aws_route53_record.aws_instance__spot
      group     = aws_route53_record.aws_instance__group
    }
  }
}
