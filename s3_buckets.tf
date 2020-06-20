locals {
  containers_with_s3_buckets = zipmap(flatten([
    for container_name, container in var.containers : [
      for bucket_global_name, bucket in var.s3_buckets :
      "${container_name}--${bucket_global_name}"
      if contains(try(keys(container.s3_buckets), []), bucket_global_name)
    ]
    ]),
    flatten([
      for container_name, container in var.containers : [
        for bucket_global_name, bucket in var.s3_buckets :
        {
          container_name     = container_name
          container          = container
          bucket_global_name = bucket_global_name
          bucket             = bucket
          permissions        = container.s3_buckets[bucket_global_name].permissions
        }
        if contains(try(keys(container.s3_buckets), []), bucket_global_name)
      ]
  ]))
}

resource "aws_s3_bucket" "s3_buckets" {
  for_each = var.s3_buckets

  bucket = each.key
  acl    = try(each.value.acl, null)

  versioning {
    enabled = try(each.value.versioning, false)
  }

  tags = {
    Name    = each.key
    Provose = var.provose_config.name
  }
}

resource "aws_iam_role_policy" "s3_buckets__container_iam__list" {
  for_each = {
    for key, config in local.containers_with_s3_buckets :
    key => config if config.permissions.list == true
  }

  name = "P-v1---${var.provose_config.name}---${each.key}---list-r-p"
  role = aws_iam_role.iam__ecs_task_execution_role[each.value.container_name].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:HeadBucket",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${each.value.bucket_global_name}",
        "arn:aws:s3:::${each.value.bucket_global_name}/*"
      ]
    }]
  })
  depends_on = [
    aws_iam_role.iam__ecs_task_execution_role
  ]
}

resource "aws_iam_role_policy" "s3_buckets__container_iam__get" {
  for_each = {
    for key, config in local.containers_with_s3_buckets :
    key => config if config.permissions.get == true
  }

  name = "P-v1---${var.provose_config.name}---${each.key}---get-r-p"
  role = aws_iam_role.iam__ecs_task_execution_role[each.value.container_name].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:GetObjectTagging",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersionTagging"
      ]
      Resource = [
        "arn:aws:s3:::${each.value.bucket_global_name}",
        "arn:aws:s3:::${each.value.bucket_global_name}/*"
      ]
    }]
  })
  depends_on = [
    aws_iam_role.iam__ecs_task_execution_role
  ]
}

resource "aws_iam_role_policy" "s3_buckets__container_iam__put" {
  for_each = {
    for key, config in local.containers_with_s3_buckets :
    key => config if config.permissions.put == true
  }

  name = "P-v1---${var.provose_config.name}---${each.key}---put-r-p"
  role = aws_iam_role.iam__ecs_task_execution_role[each.value.container_name].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "s3:PutObject"
      Resource = [
        "arn:aws:s3:::${each.value.bucket_global_name}",
        "arn:aws:s3:::${each.value.bucket_global_name}/*"
      ]
    }]
  })
  depends_on = [
    aws_iam_role.iam__ecs_task_execution_role
  ]
}

resource "aws_iam_role_policy" "s3_buckets__container_iam__delete" {
  for_each = {
    for key, config in local.containers_with_s3_buckets :
    key => config if config.permissions.delete == true
  }

  name = "P-v1---${var.provose_config.name}---${each.key}---delete-r-p"
  role = aws_iam_role.iam__ecs_task_execution_role[each.value.container_name].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "s3:DeleteObject"
      Resource = [
        "arn:aws:s3:::${each.value.bucket_global_name}",
        "arn:aws:s3:::${each.value.bucket_global_name}/*"
      ]
    }]
  })
  depends_on = [
    aws_iam_role.iam__ecs_task_execution_role
  ]
}

# == Output == 

output "s3_buckets" {
  value = {
    aws_s3_bucket = {
      s3_buckets = aws_s3_bucket.s3_buckets
    }
    aws_iam_role_policy = {
      list   = aws_iam_role_policy.s3_buckets__container_iam__list
      get    = aws_iam_role_policy.s3_buckets__container_iam__get
      put    = aws_iam_role_policy.s3_buckets__container_iam__put
      delete = aws_iam_role_policy.s3_buckets__container_iam__delete
    }
  }
}
