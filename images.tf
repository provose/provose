locals {
  ecr_repository_domain_name = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

resource "aws_ecr_repository" "images" {
  for_each = var.images
  name     = each.key
  tags = {
    Provose = var.provose_config.name
  }
  provisioner "local-exec" {
    command = (can(each.value.local_path) ? <<EOF
${local.AWS_COMMAND} ecr get-login-password | docker login --username AWS --password-stdin ${local.ecr_repository_domain_name}/${each.key}
docker build --tag ${local.ecr_repository_domain_name}/${each.key} ${each.value.local_path}
docker push ${local.ecr_repository_domain_name}/${each.key}
EOF
    : "echo Local path not provided")
  }
}


resource "aws_ecr_repository_policy" "images_ecs" {
  for_each = merge([
    for image_key, image in aws_ecr_repository.images : {
      for role_key, role in aws_iam_role.iam__ecs_task_execution_role :
      "${image_key}---${role_key}" => {
        repository = image.name
        principal  = jsonencode(role.arn)
      }
    }
  ]...)

  repository = each.value.repository
  policy = templatefile(
    "${path.module}/templates/ecr_repository_policy.json",
    {
      principal = each.value.principal
    }
  )
}


resource "aws_ecr_repository_policy" "images_ec2_on_demand_instances" {
  for_each = merge([
    for image_key, image in aws_ecr_repository.images : {
      for role_key, role in aws_iam_role.ec2_on_demand_instances :
      "${image_key}---${role_key}" => {
        repository = image.name
        principal  = jsonencode(role.arn)
      }
    }
  ]...)

  repository = each.value.repository
  policy = templatefile(
    "${path.module}/templates/ecr_repository_policy.json",
    {
      principal = each.value.principal
    }
  )
}

# == Output ==

output "images" {
  value = {
    aws_ecr_repository = {
      images = aws_ecr_repository.images
    }
    aws_ecr_repository_policy = {
      images_ecs = aws_ecr_repository_policy.images_ecs
      images_ec2_on_demand_instances = aws_ecr_repository_policy.images_ec2_on_demand_instances
    }
  }
}
