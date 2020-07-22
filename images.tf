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

resource "aws_ecr_repository_policy" "images" {
  for_each   = aws_ecr_repository.images
  repository = each.value.name
  policy = templatefile(
    "${path.module}/templates/ecr_repository_policy.json",
    {
      principal = jsonencode(concat(
        [
          for role in aws_iam_role.iam__ecs_task_execution_role : role.arn
        ],
        [
          for role in aws_iam_role.ec2_on_demand_instances : role.arn
        ],
        try(
          [aws_iam_role.jumphost[0].arn],
          []
        )
      ))
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
      images = aws_ecr_repository_policy.images
    }
  }
}
