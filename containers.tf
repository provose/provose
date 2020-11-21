locals {
  container_compatibility = {
    for name, container in var.containers :
    name => (container.instances.instance_type == "FARGATE" ? "FARGATE" :
    (container.instances.instance_type == "FARGATE_SPOT" ? "FARGATE" : "EC2"))
  }
  network_mode = {
    for name, container in var.containers :
    # For ECS Fargate containers, we use the "awsvpc" network mode because it is highly
    # performant and can give a public IP address to every single container.
    # But the "awsvpc" mode does not give public Internet access to ECS EC2 containers
    # unless the containers are both launched in a private subnet and connected to the
    # Internet through a NAT gateway. The NAT gateway costs money, so we can save that
    # money by usin the "bridge" network adapter, which is Docker's built-in virtual
    # networking interface. However, this, according to Amazon, is less performant.
    # So we only use the "bridge" mode for ECS EC2 containers.
    name => local.container_compatibility[name] == "EC2" ? "bridge" : "awsvpc"
  }
  target_type = {
    for name, container in var.containers :
    # The "awsvpc" network mode requires load balancers to use the "ip" target type.
    # Otherwise we use the "instance" target type.
    name => local.network_mode[name] == "awsvpc" ? "ip" : "instance"
  }

  # === PUBLIC HTTPS ===

  containers_with_public_https = {
    for name, container in var.containers :
    name => container
    if can(container.public.https.internal_http_port)
  }

  container_public_https_dns_names = flatten([
    for container in local.containers_with_public_https :
    container.public.https.public_dns_names
    if length(try(container.public.https.public_dns_names, [])) > 0
  ])

  container_public_https_root_domains = {
    for name in local.container_public_https_dns_names :
    name => join(".", slice(split(".", name), max(0, length(split(".", name)) - 2), length(split(".", name))))
  }

  # === VPC HTTPS ===

  containers_with_vpc_https = {
    for name, container in var.containers :
    name => container
    if can(container.vpc.https.internal_http_port)
  }

  container_vpc_https_dns_names = flatten([
    for container in local.containers_with_vpc_https :
    container.vpc.https.vpc_dns_names
    if length(try(container.vpc.https.vpc_dns_names, [])) > 0
  ])

  container_vpc_https_root_domains = {
    for name in local.container_vpc_https_dns_names :
    name => join(".", slice(split(".", name), max(0, length(split(".", name)) - 2), length(split(".", name))))
  }

  # We give a public IP to the Elastic Network Interface for all Fargate
  # and Fargate Spot instances. AWS does not allow this for EC2 instances,
  # so the answer is false.
  assign_public_ip_to_elastic_network_interface = {
    for name, container in var.containers :
    name => (
      (
        container.instances.instance_type == "FARGATE" ||
        container.instances.instance_type == "FARGATE_SPOT"
      )
    )
  }
  ecs_service_security_groups = {
    for name, container in var.containers :
    name => flatten([
      (
        can(container.public.https.internal_http_port) ||
        can(container.vpc.https.internal_http_port) ?
        [
          aws_security_group.containers__internal[name].id
        ] :
        []
      ),
      (
        aws_security_group.allow_all_egress_to_internet__new.id
      )
    ])
  }
}

resource "aws_security_group" "containers__internal" {
  for_each               = var.containers
  name                   = "P/v1/${var.provose_config.name}/${each.key}/container__internal"
  description            = "Provose security group for container ${each.key} in module ${var.provose_config.name}, opening up internal container ports."
  vpc_id                 = aws_vpc.vpc.id
  revoke_rules_on_delete = true

  # Container ingress from public HTTPS for awsvpc containers
  dynamic "ingress" {
    for_each = {
      for name, container in { (each.key) = each.value } :
      name => container.public.https.internal_http_port
      if can(container.public.https.internal_http_port) &&
      local.network_mode[name] == "awsvpc"
    }
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [aws_vpc.vpc.cidr_block]
    }
  }

  # Container ingress from VPC HTTPS for awsvpc containers
  dynamic "ingress" {
    for_each = {
      for name, container in { (each.key) = each.value } :
      name => container.vpc.https.internal_http_port
      if can(container.vpc.https.internal_http_port) &&
      local.network_mode[name] == "awsvpc"
    }
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [aws_vpc.vpc.cidr_block]
    }
  }

  # Container ingress for public and VPC HTTPS access for containers connected
  # with bridge networking. We give access to the entire ephemeral port range,
  # as the container might bind to any one of these ports.
  dynamic "ingress" {
    for_each = {
      for name, container in { (each.key) = each.value } :
      name => container
      if(can(container.public.https.internal_http_port) ||
      can(container.vpc.https.internal_http_port)) &&
      local.network_mode[name] == "bridge"
    }
    content {
      from_port   = 32768
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = [aws_vpc.vpc.cidr_block]
    }
  }

  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_ecs_cluster" "containers" {
  for_each = var.containers

  name = each.key
  capacity_providers = (
    each.value.instances.instance_type == "FARGATE" ? ["FARGATE"] :
    (
      each.value.instances.instance_type == "FARGATE_SPOT" ? ["FARGATE_SPOT"] : null
    )
  )
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    Name    = each.key
    Provose = var.provose_config.name
  }
}

resource "aws_ecs_task_definition" "containers" {
  for_each = {
    for key, container in var.containers :
    key => {
      container                = container
      image_name               = container.image.private_registry ? aws_ecr_repository.images[container.image.name].repository_url : container.image.name
      requires_compatibilities = [local.container_compatibility[key]]
      network_mode             = local.network_mode[key]
      task_role_arn            = aws_iam_role.iam__ecs_task_execution_role[key].arn
      execution_role_arn       = aws_iam_role.iam__ecs_task_execution_role[key].arn
    }
    if(
      contains(keys(local.container_compatibility), key) &&
      contains(keys(local.network_mode), key) &&
      contains(keys(aws_iam_role.iam__ecs_task_execution_role), key) &&
      (
        container.image.private_registry ?
        contains(keys(aws_ecr_repository.images), container.image.name) :
        true
      )
    )
  }

  family                   = each.key
  cpu                      = each.value.container.instances.cpu
  memory                   = each.value.container.instances.memory
  requires_compatibilities = each.value.requires_compatibilities
  network_mode             = each.value.network_mode
  task_role_arn            = each.value.task_role_arn
  execution_role_arn       = each.value.execution_role_arn

  container_definitions = templatefile(
    "${path.module}/templates/ecs_container_definition.json",
    {
      region       = data.aws_region.current.name
      task_name    = each.key
      image_name   = each.value.image_name
      image_tag    = each.value.container.image.tag
      image_name   = each.value.image_name
      cpu          = each.value.container.instances.cpu
      memory       = each.value.container.instances.memory
      network_mode = each.value.network_mode
      user         = try(each.value.container.user, null)
      command      = try(each.value.container.command, null)
      entrypoint   = try(each.value.container.entrypoint, null)
      ports = flatten([
        # This port serves public HTTPS traffic.
        (
          can(each.value.container.public.https.internal_http_port) ?
          [{
            container_port = each.value.container.public.https.internal_http_port
            # The container port and host port must match for the "awsvpc" network type.
            # When we use the "bridge" type, we say the host port is 0.
            host_port = each.value.network_mode == "awsvpc" ? each.value.container.public.https.internal_http_port : 0
            protocol  = "tcp"
          }] :
          []
        ),
        # This port serves HTTPS traffic from the VPC ALB.
        (
          can(each.value.container.vpc.https.internal_http_port) ?
          [{
            container_port = each.value.container.vpc.https.internal_http_port
            # The container port and host port must match for the "awsvpc" network type.
            # When we use the "bridge" type, we say the host port is 0.
            host_port = each.value.network_mode == "awsvpc" ? each.value.container.vpc.https.internal_http_port : 0
            protocol  = "tcp"
          }] :
          []
        )
      ])
      environment = try(each.value.container.environment, {})
      secrets = {
        for secret_env_name, secret_text_name in try(each.value.container.secrets, {}) :
        secret_env_name => aws_secretsmanager_secret_version.secrets[secret_text_name].arn
        if contains(keys(aws_secretsmanager_secret_version.secrets), secret_text_name)
      }
      efs_volumes = try(each.value.efs_volumes, {})
      bind_mounts = try(each.value.bind_mounts, [])
    }
  )

  dynamic "volume" {
    for_each = {
      for key, val in aws_efs_file_system.elastic_file_systems :
      key => val
      if can(each.value.efs_volumes[key])
    }

    content {
      name = volume.key

      efs_volume_configuration {
        file_system_id = aws_efs_file_system.elastic_file_systems[volume.key].id
        root_directory = try(each.value.efs_volumes[volume.key].host_mount, null)
      }
    }
  }
  dynamic "volume" {
    for_each = {
      for volume_name, volume_config in try(each.value.bind_mounts, {}) :
      volume_name => volume_config
    }
    content {
      name = volume.key

      host_path = volume.value.host_mount
    }
  }
  depends_on = [
    aws_ecr_repository.images,
    aws_secretsmanager_secret.secrets,
    aws_secretsmanager_secret_version.secrets,
    aws_efs_file_system.elastic_file_systems,
    aws_route53_record.elastic_file_systems
  ]
  tags = {
    Provose = var.provose_config.name
  }
}

# Terraform has an issue where it cannot replace load balancer target groups
# with another load balancer target group having the same name.
# So whenever we change a field that forces us to create a new group, we
# generate a new random name.
resource "random_id" "containers__public_https" {
  for_each = {
    for key, container in local.containers_with_public_https :
    key => {
      container   = container
      target_type = local.target_type[key]
    }
    if contains(keys(local.target_type), key)
  }
  byte_length = 4
  keepers = {
    vpc_id                             = aws_vpc.vpc.id
    internal_http_port                 = each.value.container.public.https.internal_http_port
    target_type                        = each.value.target_type
    internal_http_health_check_path    = each.value.container.public.https.internal_http_health_check_path
    internal_http_health_check_timeout = try(each.value.container.public.https.internal_http_health_check_timeout, 5)
  }
}


resource "aws_lb_target_group" "containers__public_https" {
  for_each = {
    for key, container in local.containers_with_public_https :
    key => {
      container   = container
      name_prefix = replace(random_id.containers__public_https[key].b64_url, "_", "-")
      target_type = local.target_type[key]
    }
    if(
      contains(keys(random_id.containers__public_https), key) &&
      contains(keys(local.target_type), key)
    )
  }
  name_prefix = each.value.name_prefix
  port        = each.value.container.public.https.internal_http_port
  protocol    = "HTTP"
  target_type = each.value.target_type
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_lb.public_http_https]
  health_check {
    path    = each.value.container.public.https.internal_http_health_check_path
    timeout = try(each.value.container.public.https.internal_http_health_check_timeout, 5)
    matcher = try(each.value.container.public.https.internal_http_health_check_success_status_codes, "200")
  }
  stickiness {
    # "lb_cookie" is currently the only stickiness type.
    type = "lb_cookie"
    # 86400 seconds, or exactly 1 day, is the AWS default cookie duration when
    # stickiness is enabled.
    cookie_duration = try(each.value.container.public.https.stickiness_cookie_duration_seconds, 86400)
    # only enable stickiness if the user sets how long it takes for the cookie to expire
    enabled = can(each.value.container.public.https.stickiness_cookie_duration_seconds)
  }
  tags = {
    Provose = var.provose_config.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "containers__public_https" {
  for_each = {
    for key, target_group in aws_lb_target_group.containers__public_https :
    key => {
      target_group     = target_group
      public_dns_names = local.containers_with_public_https[key].public.https.public_dns_names
    }
    if(
      length(aws_lb_listener.public_http_https__443) > 0 &&
      contains(keys(local.containers_with_public_https), key)
    )
  }
  listener_arn = aws_lb_listener.public_http_https__443[0].arn
  action {
    type             = "forward"
    target_group_arn = each.value.target_group.arn
  }
  condition {
    host_header {
      values = each.value.public_dns_names
    }
  }
}

# Terraform has an issue where it cannot replace load balancer target groups
# with another load balancer target group having the same name.
# So whenever we change a field that forces us to create a new group, we
# generate a new random name.
resource "random_id" "containers__vpc_https" {
  for_each = {
    for key, container in local.containers_with_vpc_https :
    key => {
      container   = container
      target_type = local.target_type[key]
    }
    if contains(keys(local.target_type), key)
  }
  byte_length = 4
  keepers = {
    vpc_id                             = aws_vpc.vpc.id
    internal_http_port                 = each.value.container.vpc.https.internal_http_port
    target_type                        = each.value.target_type
    internal_http_health_check_path    = each.value.container.vpc.https.internal_http_health_check_path
    internal_http_health_check_timeout = try(each.value.container.vpc.https.internal_http_health_check_timeout, 5)
  }
}


resource "aws_lb_target_group" "containers__vpc_https" {
  for_each = {
    for key, container in local.containers_with_vpc_https :
    key => {
      container   = container
      name_prefix = replace(random_id.containers__vpc_https[key].b64_url, "_", "-")
      target_type = local.target_type[key]
    }
    if(
      contains(keys(random_id.containers__vpc_https), key) &&
      contains(keys(local.target_type), key)
    )
  }
  name_prefix = each.value.name_prefix
  port        = each.value.container.vpc.https.internal_http_port
  protocol    = "HTTP"
  target_type = each.value.target_type
  vpc_id      = aws_vpc.vpc.id
  depends_on = [
    aws_lb.vpc_http_https
  ]
  health_check {
    path    = each.value.container.vpc.https.internal_http_health_check_path
    timeout = try(each.value.container.vpc.https.internal_http_health_check_timeout, 5)
    matcher = try(each.value.container.vpc.https.internal_http_health_check_success_status_codes, "200")
  }
  stickiness {
    # "lb_cookie" is currently the only stickiness type.
    type = "lb_cookie"
    # 86400 seconds, or exactly 1 day, is the AWS default cookie duration when
    # stickiness is enabled.
    cookie_duration = try(each.value.container.vpc.https.stickiness_cookie_duration_seconds, 86400)
    # only enable stickiness if the user sets how long it takes for the cookie to expire
    enabled = can(each.value.container.vpc.https.stickiness_cookie_duration_seconds)
  }
  tags = {
    Provose = var.provose_config.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "containers__vpc_https" {
  for_each = {
    for key, container in local.containers_with_vpc_https :
    key => {
      container        = container
      target_group_arn = aws_lb_target_group.containers__vpc_https[key].arn
    }
    if contains(keys(aws_lb_target_group.containers__vpc_https), key)
  }
  listener_arn = aws_lb_listener.vpc_http_https__port_443[0].arn
  action {
    type             = "forward"
    target_group_arn = each.value.target_group_arn
  }
  condition {
    host_header {
      values = each.value.container.vpc.https.vpc_dns_names
    }
  }
}

resource "aws_ecs_service" "containers" {
  for_each = {
    for key, container in var.containers :
    key => {
      container = container
      # The platform version must be null when specifying an EC2 launch type.
      # We need platform version 1.4.0 or better in order to use
      # Amazon Elastic Filesystem (EFS) with Fargate instances.
      platform_version = local.container_compatibility[key] == "EC2" ? null : "1.4.0"
      # If we are launching a Fargate container, then we use the
      # "capacity_provider_strategy" block as opposed to a launch_type. We only
      # use the launch_type for EC2 containers.
      launch_type                 = local.container_compatibility[key] == "EC2" ? "EC2" : null
      cluster_id                  = aws_ecs_cluster.containers[key].id
      task_definition_arn         = aws_ecs_task_definition.containers[key].arn
      target_group_arn            = aws_lb_target_group.containers__public_https[key].arn
      task_definition_family      = aws_ecs_task_definition.containers[key].family
      ecs_service_security_groups = local.ecs_service_security_groups[key]
      assign_public_ip            = local.assign_public_ip_to_elastic_network_interface[key]
    }
    if(
      contains(keys(local.container_compatibility), key) &&
      contains(keys(aws_ecs_cluster.containers), key) &&
      contains(keys(aws_ecs_task_definition.containers), key) &&
      contains(keys(aws_lb_target_group.containers__public_https), key) &&
      contains(keys(local.ecs_service_security_groups), key) &&
      contains(keys(local.assign_public_ip_to_elastic_network_interface), key)
    )
  }

  name = each.key

  platform_version = each.value.platform_version
  desired_count    = each.value.container.instances.container_count
  launch_type      = each.value.launch_type
  cluster          = each.value.cluster_id
  task_definition  = each.value.task_definition_arn

  dynamic "capacity_provider_strategy" {
    for_each = {
      for capacity_provider_name in ["FARGATE", "FARGATE_SPOT"] :
      capacity_provider_name => capacity_provider_name
      if capacity_provider_name == each.value.container.instances.instance_type
    }
    content {
      capacity_provider = each.value.container.instances.instance_type
      weight            = 1
    }
  }

  dynamic "load_balancer" {
    for_each = {
      for name, target_group in aws_lb_target_group.containers__public_https :
      name => var.containers[name]
      if(
        name == each.key &&
        can(var.containers[name].public.https.internal_http_port)
      )
    }
    content {
      target_group_arn = each.value.target_group_arn
      container_name   = each.value.task_definition_family
      container_port   = each.value.container.public.https.internal_http_port
    }
  }

  dynamic "load_balancer" {
    for_each = {
      for name, target_group in aws_lb_target_group.containers__vpc_https :
      name => var.containers[name]
      if(
        name == each.key &&
        can(var.containers[name].vpc.https.internal_http_port)
      )
    }
    content {
      target_group_arn = each.value.target_group_arn
      container_name   = each.value.task_definition_family
      container_port   = each.value.container.public.https.internal_http_port
    }
  }

  # The `network_configuration` block is only supported when the `awsvpc`
  # network mode is being used.
  dynamic "network_configuration" {
    for_each = {
      for name, container in { (each.key) = each.value } :
      name => container
      if local.network_mode[name] == "awsvpc"
    }
    content {
      subnets          = aws_subnet.vpc[*].id
      security_groups  = each.value.ecs_service_security_groups
      assign_public_ip = each.value.assign_public_ip
    }
  }

  depends_on = [
    aws_internet_gateway.vpc,
    aws_ecs_task_definition.containers,
    aws_ecs_cluster.containers,
    aws_lb_target_group.containers__public_https
  ]
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_instance" "containers__instance" {
  for_each = zipmap(
    flatten([
      for container_name, ecs_instance_profile in module.aws_iam_instance_profile__containers.instance_profiles : [
        for i in range(var.containers[container_name].instances.instance_count) :
        join("-", [container_name, "host", i])
        if(
          ! can(var.containers[container_name].instances.spot_instance)
        )
      ]
      if local.container_compatibility[container_name] == "EC2"
    ]),
    flatten([
      for container_name, ecs_instance_profile in module.aws_iam_instance_profile__containers.instance_profiles : [
        for i in range(var.containers[container_name].instances.instance_count) :
        {
          index          = i
          container_name = container_name
          container      = var.containers[container_name]
        }
        if(
          ! can(var.containers[container_name].instances.spot_instance)
        )
      ]
      if local.container_compatibility[container_name] == "EC2"
    ])
  )
  associate_public_ip_address = true
  iam_instance_profile        = module.aws_iam_instance_profile__containers.instance_profiles[each.value.container_name].name
  ami                         = data.aws_ami.amazon_linux_2_ecs_gpu_hvm_ebs.id
  instance_type               = each.value.container.instances.instance_type
  # element wraps around each.value.index if we are creating more AWS
  # instances than we have subnets.
  # We have to launch in a public subnet to access ECS.
  subnet_id = element(sort([
    for subnet in aws_subnet.vpc : subnet.id if subnet.map_public_ip_on_launch == true
  ]), each.value.index)
  vpc_security_group_ids = concat(
    local.ecs_service_security_groups[each.value.container_name],
    [aws_security_group.vpc_ssh.id]
  )
  key_name = try(each.value.container.instances.key_name, null)

  dynamic "ebs_block_device" {
    for_each = {
      for device_name, volume in try(each.value.container.instances.ebs_volumes, {}) :
      device_name => volume
    }
    content {
      device_name           = ebs_block_device.key
      volume_size           = ebs_block_device.value.volume_size_gb
      volume_type           = try(ebs_block_device.value.volume_type, null)
      delete_on_termination = try(ebs_block_device.value.delete_on_termination, false)
    }
  }

  depends_on = [
    aws_internet_gateway.vpc,
    module.aws_iam_instance_profile__containers.instance_profiles,
    aws_ecs_cluster.containers,
    aws_ecs_service.containers,
  ]

  tags = {
    Name    = each.key
    Provose = var.provose_config.name
  }
  user_data = <<EOF
#!/bin/bash
set -Eeuxo pipefail
echo ECS_CLUSTER=${each.value.container_name} >> /etc/ecs/ecs.config
echo ECS_BACKEND_HOST= >> /etc/ecs/ecs.config

declare -a EBS_VOLUMES=(${
  join(
    " ",
    [for volume_name in keys(try(each.value.container.instances.ebs_volumes, {})) :
    join("", ["\"", volume_name, "\""])]
  )
  })

declare -a EBS_VOLUME_MOUNT_TARGETS=(${
  join(
    " ",
    [for volume_name, volume in try(each.value.container.instances.ebs_volumes, {}) :
    join("", ["\"", volume.host_mount, "\""])]
  )
})

for i in $${!EBS_VOLUMES[*]}
do 
  # Format the EBS volume as ext4, but only if it has not already formatted as ext4.
  # Note that this will format EBS volumes that are formatted to a different filesystem.
  if file -Lsb $${EBS_VOLUMES[$i]} | grep -vq ext4
  then
    mkfs -t ext4 $${EBS_VOLUMES[$i]}
  fi
  mkdir -p $${EBS_VOLUME_MOUNT_TARGETS[$i]}
  mount $${EBS_VOLUMES[$i]} $${EBS_VOLUME_MOUNT_TARGETS[$i]}
  echo -e "$${EBS_VOLUMES[$i]}\t$${EBS_VOLUME_MOUNT_TARGETS[$i]}\text4\tdefaults\t0\t0" >> /etc/fstab
  mount -a
done

yum update -y
yum install -y amazon-efs-utils

${try(each.value.container.instances.bash_user_data, "")}

EOF
}

resource "aws_route53_record" "containers__instance" {
  for_each = aws_instance.containers__instance

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.provose_config.internal_subdomain}"
  type    = "A"
  ttl     = "5"
  records = [each.value.private_ip]
}

data "aws_route53_zone" "external_dns__for_containers" {
  for_each     = local.container_public_https_root_domains
  name         = each.value
  private_zone = false
}

resource "aws_route53_record" "containers__public_https" {
  for_each = data.aws_route53_zone.external_dns__for_containers

  zone_id = each.value.zone_id
  name    = each.key
  type    = "A"
  alias {
    name                   = aws_lb.public_http_https[0].dns_name
    zone_id                = aws_lb.public_http_https[0].zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "containers__public_https" {
  for_each          = aws_route53_record.containers__public_https
  domain_name       = each.key
  validation_method = "DNS"
  options {
    certificate_transparency_logging_preference = "ENABLED"
  }
}

resource "aws_route53_record" "containers__public_https_validation" {
  for_each = aws_acm_certificate.containers__public_https

  name       = tolist(each.value.domain_validation_options)[0].resource_record_name
  type       = tolist(each.value.domain_validation_options)[0].resource_record_type
  zone_id    = data.aws_route53_zone.external_dns__for_containers[each.value.domain_name].zone_id
  records    = [tolist(each.value.domain_validation_options)[0].resource_record_value]
  ttl        = 60
  depends_on = [aws_acm_certificate.containers__public_https]
}

resource "aws_acm_certificate_validation" "containers__public_https_validation" {
  for_each = {
    for key, certificate in aws_acm_certificate.containers__public_https :
    key => {
      certificate_arn         = certificate.arn
      validation_record_fqdns = [aws_route53_record.containers__public_https_validation[key].fqdn]
    }
    if contains(keys(aws_route53_record.containers__public_https_validation), key)
  }
  certificate_arn         = each.value.certificate_arn
  validation_record_fqdns = each.value.validation_record_fqdns
}

resource "aws_lb_listener_certificate" "containers__public_https_validation" {
  for_each        = length(aws_lb_listener.public_http_https__443) > 0 ? aws_acm_certificate_validation.containers__public_https_validation : {}
  listener_arn    = aws_lb_listener.public_http_https__443[0].arn
  certificate_arn = each.value.certificate_arn

  depends_on = [
    aws_lb_listener.public_http_https__443
  ]
}

resource "aws_route53_record" "containers__vpc_https" {
  for_each = { for x in local.container_vpc_https_dns_names : x => x }

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = each.value
  type    = "A"
  alias {
    name                   = aws_lb.vpc_http_https[0].dns_name
    zone_id                = aws_lb.vpc_http_https[0].zone_id
    evaluate_target_health = false
  }
}

# Now we are repeating all of the aws_instance stuff, but with an aws_instance_spot_request
# instead....

resource "aws_spot_instance_request" "containers__instance" {
  for_each = zipmap(
    flatten([
      for container_name, container_compatibility in local.container_compatibility : [
        for i in range(var.containers[container_name].instances.instance_count) :
        join("-", [container_name, "host", i])
        if can(var.containers[container_name].instances.spot_instance)
      ]
      if container_compatibility == "EC2"
    ]),
    flatten([
      for container_name, container_compatibility in local.container_compatibility : [
        for i in range(var.containers[container_name].instances.instance_count) :
        {
          index          = i
          container_name = container_name
          container      = var.containers[container_name]
        }
        if can(var.containers[container_name].instances.spot_instance)
      ]
      if container_compatibility == "EC2"
    ])
  )
  # Special spot instance 
  wait_for_fulfillment = true
  # Below this line is `aws_instance` parameters
  associate_public_ip_address = true
  iam_instance_profile        = module.aws_iam_instance_profile__containers.instance_profiles[each.value.container_name].name
  ami                         = data.aws_ami.amazon_linux_2_ecs_gpu_hvm_ebs.id
  instance_type               = each.value.container.instances.instance_type
  # element wraps around each.value.index if we are creating more AWS
  # instances than we have subnets.
  # We have to launch in a public subnet to access ECS.
  subnet_id = element(sort([
    for subnet in aws_subnet.vpc : subnet.id if subnet.map_public_ip_on_launch == true
  ]), each.value.index)
  vpc_security_group_ids = concat(
    local.ecs_service_security_groups[each.value.container_name],
    [aws_security_group.vpc_ssh.id]
  )
  key_name = try(each.value.container.instances.key_name, null)

  dynamic "ebs_block_device" {
    for_each = {
      for device_name, volume in try(each.value.container.instances.ebs_volumes, {}) :
      device_name => volume
    }
    content {
      device_name           = ebs_block_device.key
      volume_size           = ebs_block_device.value.volume_size_gb
      volume_type           = try(ebs_block_device.value.volume_type, null)
      delete_on_termination = try(ebs_block_device.value.delete_on_termination, false)
    }
  }

  depends_on = [
    aws_internet_gateway.vpc,
    module.aws_iam_instance_profile__containers.instance_profiles,
    aws_ecs_cluster.containers,
    aws_ecs_service.containers,
  ]

  tags = {
    Name    = each.key
    Provose = var.provose_config.name
  }
  user_data = <<EOF
#!/bin/bash
set -Eeuxo pipefail
echo NO_PROXY=169.254.169.254,169.254.170.2,/var/run/docker.sock >> /etc/ecs/ecs.config
echo ECS_CLUSTER=${each.value.container_name} >> /etc/ecs/ecs.config
echo ECS_BACKEND_HOST= >> /etc/ecs/ecs.config

declare -a EBS_VOLUMES=(${
  join(
    " ",
    [for volume_name in keys(try(each.value.container.instances.ebs_volumes, {})) :
    join("", ["\"", volume_name, "\""])]
  )
  })

declare -a EBS_VOLUME_MOUNT_TARGETS=(${
  join(
    " ",
    [for volume_name, volume in try(each.value.container.instances.ebs_volumes, {}) :
    join("", ["\"", volume.host_mount, "\""])]
  )
})

for i in $${!EBS_VOLUMES[*]}
do 
  # Format the EBS volume as ext4, but only if it has not already formatted as ext4.
  # Note that this will format EBS volumes that are formatted to a different filesystem.
  if file -Lsb $${EBS_VOLUMES[$i]} | grep -vq ext4
  then
    mkfs -t ext4 $${EBS_VOLUMES[$i]}
  fi
  mkdir -p $${EBS_VOLUME_MOUNT_TARGETS[$i]}
  mount $${EBS_VOLUMES[$i]} $${EBS_VOLUME_MOUNT_TARGETS[$i]}
  echo -e "$${EBS_VOLUMES[$i]}\t$${EBS_VOLUME_MOUNT_TARGETS[$i]}\text4\tdefaults\t0\t0" >> /etc/fstab
  mount -a
done

yum update -y
yum install -y amazon-efs-utils

${try(each.value.container.instances.bash_user_data, "")}

EOF
}

resource "aws_route53_record" "containers__instance_spot" {
  for_each = aws_spot_instance_request.containers__instance

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.provose_config.internal_subdomain}"
  type    = "A"
  ttl     = "5"
  records = [each.value.private_ip]
}


# == Output == 

output "containers" {
  value = {
    aws_security_group = {
      containers__internal = aws_security_group.containers__internal
    }
    aws_ecs_cluster = {
      containers = aws_ecs_cluster.containers
    }
    aws_ecs_task_definition = {
      containers = aws_ecs_task_definition.containers
    }
    aws_lb_target_group = {
      containers__public_https = aws_lb_target_group.containers__public_https
      containers__vpc_https    = aws_lb_target_group.containers__vpc_https
    }
    aws_lb_listener_rule = {
      containers__public_https = aws_lb_listener_rule.containers__public_https
      containers__vpc_https    = aws_lb_listener_rule.containers__vpc_https
    }
    aws_ecs_service = {
      containers = aws_ecs_service.containers
    }
    aws_instance = {
      containers__instance = aws_instance.containers__instance
    }
    aws_route53_record = {
      containers__instance                = aws_route53_record.containers__instance
      containers__public_https            = aws_route53_record.containers__public_https
      containers__public_https_validation = aws_route53_record.containers__public_https_validation
      containers__vpc_https               = aws_route53_record.containers__vpc_https
      containers__instance_spot           = aws_route53_record.containers__instance_spot
    }
    aws_route53_zone = {
      external_dns__for_containers = data.aws_route53_zone.external_dns__for_containers
    }
    aws_acm_certificate = {
      containers__public_https = aws_acm_certificate.containers__public_https
    }
    aws_acm_certificate_validation = {
      containers__public_https_validation = aws_acm_certificate_validation.containers__public_https_validation
    }
    aws_lb_listener_certificate = {
      containers__public_https_validation = aws_lb_listener_certificate.containers__public_https_validation
    }
    aws_spot_instance_request = {
      containers__instance = aws_spot_instance_request.containers__instance
    }
  }
}
