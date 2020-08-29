resource "aws_iam_role" "batch__execution_role" {
  count = length(var.batch) > 0 ? 1 : 0
  name  = "P-v1---${var.provose_config.name}---batch-ex-e-t-e-r"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "batch__execution_role" {
  count      = length(var.batch) > 0 ? 1 : 0
  role       = aws_iam_role.batch__execution_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

module "aws_iam_instance_profile__batch__execution_role" {
  source      = "./modules/iam_instance_profiles"
  aws_command = local.AWS_COMMAND
  profile_configs = {
    for role in aws_iam_role.batch__execution_role :
    "main" => {
      instance_profile_name = "P-v1---${var.provose_config.name}---batch-ex-i-p"
      path                  = "/"
      role_name             = role.name
    }
  }
}

resource "aws_iam_role" "batch__service_role" {
  count = length(var.batch) > 0 ? 1 : 0
  name  = "P-v1---${var.provose_config.name}---batch-s-r"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "batch.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "batch__service_role" {
  count      = length(var.batch) > 0 ? 1 : 0
  role       = aws_iam_role.batch__service_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_iam_role" "batch__spot_fleet_role" {
  count = length(var.batch) > 0 ? 1 : 0
  name  = "P-v1---${var.provose_config.name}---batch-spot-fleet-r"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "spotfleet.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "batch__spot_fleet_role" {
  count      = length(var.batch) > 0 ? 1 : 0
  role       = aws_iam_role.batch__spot_fleet_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

resource "aws_security_group" "batch" {
  for_each = var.batch

  name = "P/v1/${var.provose_config.name}/${each.key}/batch"

  description            = "Provose security group for an AWS Batch Compute Environment named ${each.key} in module ${var.provose_config.name}."
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

resource "aws_batch_compute_environment" "batch" {
  for_each = var.batch

  compute_environment_name = each.key

  compute_resources {
    instance_role       = module.aws_iam_instance_profile__batch__execution_role.instance_profiles["main"].arn
    spot_iam_fleet_role = aws_iam_role.batch__spot_fleet_role[0].arn
    bid_percentage      = 100
    instance_type       = each.value.instances.instance_types
    type                = each.value.instances.compute_environment_type
    max_vcpus           = each.value.instances.max_vcpus
    min_vcpus           = each.value.instances.min_vcpus

    security_group_ids = [aws_security_group.batch[each.key].id]
    subnets            = aws_subnet.vpc[*].id
    tags = {
      Provose       = var.provose_config.name
      Provose_Batch = each.key
    }
  }

  service_role = aws_iam_role.batch__service_role[0].arn
  type         = "MANAGED"
  depends_on = [
    aws_iam_role_policy_attachment.batch__service_role,
    aws_security_group.batch
  ]
}

resource "aws_batch_job_queue" "batch" {
  for_each = zipmap(
    flatten([
      for compute_environment_name, compute_environment_config in var.batch : [
        for queue_name, queue_config in try(var.batch[compute_environment_name].queues, []) :
        join("-", [compute_environment_name, "queue", queue_name])
      ]
    ]),
    flatten([
      for compute_environment_name, compute_environment_config in var.batch : [
        for queue_name, queue_config in try(var.batch[compute_environment_name].queues, []) :
        merge(
          {
            compute_environment_name = compute_environment_name
            compute_environment_arn  = aws_batch_compute_environment.batch[compute_environment_name].arn
          },
          queue_config
        )
      ]
    ])
  )
  name     = each.key
  state    = each.value.state
  priority = each.value.priority
  compute_environments = [
    each.value.compute_environment_arn
  ]
}

resource "aws_batch_job_definition" "batch" {
  for_each = zipmap(
    flatten([
      for compute_environment_name, compute_environment_config in var.batch : [
        for job_name, job_config in try(var.batch[compute_environment_name].jobs, []) :
        join("-", [compute_environment_name, "job", job_name])
      ]
    ]),
    flatten([
      for compute_environment_name, compute_environment_config in var.batch : [
        for job_name, job_config in try(var.batch[compute_environment_name].jobs, []) :
        merge(
          {
            compute_environment_name = compute_environment_name
          },
          job_config
        )
      ]
    ])
  )
  name = "tf_test_batch_job_definition"
  type = "container"

  container_properties = templatefile(
    "${path.module}/templates/batch_job_definition.json",
    {
      image_tag    = each.value.image.tag
      image_name   = each.value.image.private_registry ? aws_ecr_repository.images[each.value.image.name].repository_url : each.value.image.name
      vcpus        = each.value.vcpus
      memory       = each.value.memory
      user         = try(each.value.user, null)
      privileged   = try(each.value.privileged, null)
      command      = try(each.value.command, null)
      environment  = try(each.value.environment, {})
      job_role_arn = null
    }
  )
}

# == Output == 

output "batch" {
  value = {
    aws_iam_role = {
      batch__execution_role  = aws_iam_role.batch__execution_role
      batch__service_role    = aws_iam_role.batch__service_role
      batch__spot_fleet_role = aws_iam_role.batch__spot_fleet_role
    }
    aws_iam_instance_profile = {
      batch__execution_role = module.aws_iam_instance_profile__batch__execution_role.instance_profiles
    }
    aws_security_group = {
      batch = aws_security_group.batch
    }
    aws_batch_compute_environment = {
      batch = aws_batch_compute_environment.batch
    }
    aws_batch_job_queue = {
      batch = aws_batch_job_queue.batch
    }
    aws_batch_job_definition = {
      batch = aws_batch_job_definition.batch
    }
  }
}
