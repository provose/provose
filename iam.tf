# Generally all of our containers are allowed access to the same stuff,
# (just to simplify things), but we need different roles because different
# containers are allowed access to different secrets.
resource "aws_iam_role" "iam__ecs_task_execution_role" {
  for_each = var.container

  name               = "${each.key}-iam-ecs-task-execution-role"
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
    Powercloud = var.name
  }

}

resource "aws_iam_instance_profile" "iam__ecs_instance_profile" {
  for_each = {
    for container_name, role in aws_iam_role.iam__ecs_task_execution_role :
    container_name => role
    if local.launch_type[container_name] ==
    "EC2"
  }

  name_prefix = "${each.key}-iam-ec2-ecs-instance-profile"
  role        = each.value.name
}

resource "aws_iam_role_policy" "iam__ecs_task_execution_role_policy_for_secrets" {
  for_each = { for key, val in var.container : key => val if length(try(val.secrets, {})) > 0 }
  name     = "${each.key}-iam-ecs-task-execution-role-policy-for-secrets"
  role     = aws_iam_role.iam__ecs_task_execution_role[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        for env_var_name, secret_name in each.value.secrets :
        aws_secretsmanager_secret.secrets[secret_name].arn
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
resource "aws_iam_role_policy" "iam" {
  for_each = var.container
  name     = "${each.key}-policy"
  role     = aws_iam_role.iam__ecs_task_execution_role[each.key].id
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
      iam__ecs_instance_profile = aws_iam_instance_profile.iam__ecs_instance_profile
    }
    aws_iam_role_policy = {
      iam__ecs_task_execution_role_policy_for_secrets = aws_iam_role_policy.iam__ecs_task_execution_role_policy_for_secrets
      iam                                             = aws_iam_role_policy.iam
    }

  }
}
