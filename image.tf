# TODO: Make this indexed on the list of distinct images, not the list of containers.
resource "aws_ecr_repository" "image" {
  for_each = {
    for image_name in distinct([
      for container_name, container in var.container :
      container.image.name
      if container.image.private_registry
    ]) : image_name => image_name
  }
  name = each.value
  tags = {
    Powercloud = var.name
  }
}

resource "aws_ecr_repository_policy" "image" {
  for_each = {
    for key, val in var.container :
    key => val if val.image.private_registry == true
  }

  repository = aws_ecr_repository.image[each.value.image.name].name
  policy = templatefile("${path.module}/templates/ecr_repository_policy.json",
  { principal = jsonencode([for role in aws_iam_role.iam__ecs_task_execution_role : role.arn]) })
}

# == Output ==

output "image" {
  value = {
    aws_ecr_repository = {
      image = aws_ecr_repository.image
    }
    aws_ecr_repository_policy = {
      image = aws_ecr_repository_policy.image
    }
  }
}
