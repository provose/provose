# Generally all of our containers are allowed access to the same stuff,
# (just to simplify things), but we need different roles because different
# containers are allowed access to different secrets.
resource "aws_iam_role" "iam__ecs_task_execution_role" {
  for_each = var.containers

  name = "P-v1---${var.provose_config.name}---${each.key}---e-t-e-r"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = sort([
            "ec2.amazonaws.com",
            "ecs-tasks.amazonaws.com",
          ])
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Provose = var.provose_config.name
  }
}

# Allow connecting to the instance with AWS Session Manager.
resource "aws_iam_role_policy_attachment" "iam__ecs_task_execution_role__ssm" {
  for_each   = aws_iam_role.iam__ecs_task_execution_role
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

module "aws_iam_instance_profile__containers" {
  source      = "./modules/iam_instance_profiles"
  aws_command = local.AWS_COMMAND
  profile_configs = {
    for container_name, role in aws_iam_role.iam__ecs_task_execution_role :
    (container_name) => {
      instance_profile_name = "P-v1---${var.provose_config.name}---${container_name}---i-p"
      path                  = "/"
      role_name             = role.name
    }
    if try(local.container_compatibility[container_name] == "EC2", false)
  }
}

resource "aws_iam_role_policy" "iam__ecs_task_execution_role_policy_for_secrets" {
  for_each = {
    for key, container in var.containers :
    key => {
      container = container
      role      = aws_iam_role.iam__ecs_task_execution_role[key]
    }
    if(
      length(try(container.secrets, {})) > 0 &&
      contains(keys(aws_iam_role.iam__ecs_task_execution_role), key)
    )
  }
  # TODO: This name here is too long. We need to replace it with a better one.
  name = "P-v1---${var.provose_config.name}---${each.key}---iam-ecs-task-execution-role-policy-for-secrets"
  role = each.value.role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        for env_var_name, secret_name in each.value.container.secrets :
        aws_secretsmanager_secret.secrets[secret_name].arn
        if contains(keys(aws_secretsmanager_secret.secrets), secret_name)
      ]
    }]
  })
  depends_on = [
    aws_secretsmanager_secret.secrets,
    aws_secretsmanager_secret_version.secrets
  ]
}

# This is a blanket policy that generally allows the pulling of private ECR
# images, the creating and joining of ECR clusters, and the creating
# and joining of CloudWatch stuff.
# TODO: Tighten this up so that containers only have the specific permissions on the instances needed.
resource "aws_iam_role_policy" "iam" {
  #  for_each = var.containers
  for_each = aws_iam_role.iam__ecs_task_execution_role
  name     = "P-v1---${var.provose_config.name}---${each.key}---r-p"
  role     = each.value.id
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

# == Output ==

output "iam" {
  value = {
    aws_iam_role = {
      iam__ecs_task_execution_role = aws_iam_role.iam__ecs_task_execution_role
    }
    aws_iam_instance_profile = {
      iam__ecs_instance_profile = module.aws_iam_instance_profile__containers.instance_profiles
    }
    aws_iam_role_policy = {
      iam__ecs_task_execution_role_policy_for_secrets = aws_iam_role_policy.iam__ecs_task_execution_role_policy_for_secrets
      iam                                             = aws_iam_role_policy.iam
    }

  }
}
