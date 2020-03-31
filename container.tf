locals {
  launch_type = {
    for name, container in var.container :
    name => (container.instances.instance_type == "FARGATE" ? "FARGATE" :
    (container.instances.instance_type == "FARGATE_SPOT" ? "FARGATE_SPOT" : "EC2"))
  }
  network_mode = {
    for name, container in var.container :
    # For ECS Fargate containers, we use the "awsvpc" network mode because it is highly
    # performant and can give a public IP address to every single container.
    # But the "awsvpc" mode does not give public Internet access to ECS EC2 containers
    # unless the containers are both launched in a private subnet and connected to the
    # Internet through a NAT gateway. The NAT gateway costs money, so we can save that
    # money by usin the "bridge" network adapter, which is Docker's built-in virtual
    # networking interface. However, this, according to Amazon, is less performant.
    # So we only use the "bridge" mode for ECS EC2 containers.
    name => local.launch_type[name] == "EC2" ? "bridge" : "awsvpc"
  }
  target_type = {
    for name, container in var.container :
    # The "awsvpc" network mode requires load balancers to use the "ip" target type.
    # Otherwise we use the "instance" target type.
    name => local.network_mode[name] == "awsvpc" ? "ip" : "instance"
  }
  containers_with_public_https = {
    for name, container in var.container :
    name => container
    if can(container.public.https.internal_http_port)
  }

  container_public_dns_names = flatten([
    for container in local.containers_with_public_https :
    container.public.https.public_dns_names
    if length(try(container.public.https.public_dns_names, [])) > 0
  ])

  container_public_root_domains = {
    for name in local.container_public_dns_names :
    name => join(".", slice(split(".", name), max(0, length(split(".", name)) - 2), length(split(".", name))))
  }
  containers_with_vpc_https = {
    for name, container in var.container :
    name => container
    if can(container.vpc.https.internal_http_port)
  }

  container_vpc_dns_names = flatten([
    for container in local.containers_with_vpc_https :
    container.vpc.https.vpc_dns_names
    if length(try(container.vpc.https.vpc_dns_names, [])) > 0
  ])

  container_vpc_root_domains = {
    for name in local.container_vpc_dns_names :
    name => join(".", slice(split(".", name), max(0, length(split(".", name)) - 2), length(split(".", name))))
  }

  # We give a public IP to the Elastic Network Interface for all Fargate
  # and Fargate Spot instances. AWS does not allow this for EC2 instances,
  # so the answer is false.
  assign_public_ip_to_elastic_network_interface = {
    for name, container in var.container :
    name => (
      (
        container.instances.instance_type == "FARGATE" ||
        container.instances.instance_type == "FARGATE_SPOT"
      )
    )
  }
  ecs_service_security_groups = {
    for name, container in var.container :
    name => flatten([
      (
        can(container.public.https.internal_http_port) ||
        can(container.vpc.https.internal_http_port) ?
        [
          aws_security_group.container__internal_http_port[name].id
        ] :
        []
      ),
      (
        aws_security_group.allow_all_egress_to_internet.id
      )
    ])
  }
}

resource "aws_security_group" "container__internal_http_port" {
  for_each = var.container

  vpc_id      = aws_vpc.vpc.id
  name        = "${var.name}/${each.key}/container-internal"
  description = "Provose security group for container ${each.key} in module ${var.name}, opening up internal container ports."

  # Container ingress from public HTTPS for awsvpc containers
  dynamic "ingress" {
    for_each = {
      for name, container in { (each.key) = each.value } :
      name => container.public.https.internal_http_port
      if can(container.public.https.internal_http_port) &&
      local.launch_type[name] == "awsvpc"
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
      local.launch_type[name] == "awsvpc"
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
    Provose = var.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_cluster" "container" {
  for_each = var.container

  name = each.key
  tags = {
    Name    = each.key
    Provose = var.name
  }
}

resource "aws_ecs_task_definition" "container" {
  for_each = var.container

  family                   = each.key
  cpu                      = each.value.instances.cpu
  memory                   = each.value.instances.memory
  requires_compatibilities = [local.launch_type[each.key]]
  network_mode             = local.network_mode[each.key]
  task_role_arn            = aws_iam_role.iam__ecs_task_execution_role[each.key].arn
  execution_role_arn       = aws_iam_role.iam__ecs_task_execution_role[each.key].arn

  container_definitions = templatefile(
    "${path.module}/templates/ecs_container_definition.json",
    {
      region       = data.aws_region.current.name
      task_name    = each.key
      image_tag    = each.value.image.tag
      image_name   = each.value.image.private_registry ? aws_ecr_repository.image[each.value.image.name].repository_url : each.value.image.name
      cpu          = each.value.instances.cpu
      memory       = each.value.instances.memory
      network_mode = local.network_mode[each.key]
      entrypoint   = try(each.value.entrypoint, null)
      ports = flatten([
        # This port serves public HTTPS traffic.
        (
          can(each.value.public.https.internal_http_port) ?
          [{
            "container_port" = each.value.public.https.internal_http_port
            "host_port"      = 0
            "protocol"       = "tcp"
          }] :
          []
        ),
        # This port serves HTTPS traffic from the VPC ALB.
        (
          can(each.value.vpc.https.internal_http_port) ?
          [{
            "container_port" = each.value.vpc.https.internal_http_port
            "host_port"      = 0
            "protocol"       = "tcp"
          }] :
          []
        )
      ])
      environment = try(each.value.environment, {})
      secrets = {
        for secret_env_name, secret_text_name in try(each.value.secrets, {}) :
        secret_env_name => aws_secretsmanager_secret.secrets[secret_text_name].arn
      }
      efs_volumes = try(each.value.efs_volumes, {})
      bind_mounts = try(each.value.bind_mounts, [])
    }
  )

  dynamic "volume" {
    for_each = {
      for key, val in aws_efs_file_system.efs :
      key => val
      if can(each.value.efs_volumes[key])
    }

    content {
      name = volume.key

      docker_volume_configuration {
        scope         = "shared"
        autoprovision = true
        driver        = "local"

        driver_opts = {
          "type"   = "efs"
          "device" = "${aws_route53_record.efs[volume.key].fqdn}:/"
          "o"      = "addr=${aws_route53_record.efs[volume.key].fqdn},efsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,nosuid"
        }
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
    aws_ecr_repository.image,
    aws_secretsmanager_secret.secrets,
    aws_secretsmanager_secret_version.secrets,
    aws_efs_file_system.efs,
    aws_route53_record.efs
  ]
  tags = {
    Provose = var.name
  }
}

# Terraform has an issue where it cannot replace load balancer target groups
# with another load balancer target group having the same name.
# So whenever we change a field that forces us to create a new group, we
# generate a new random name.
resource "random_id" "container__public_https" {
  for_each    = local.containers_with_public_https
  byte_length = 4
  keepers = {
    vpc_id                          = aws_vpc.vpc.id
    internal_http_port              = each.value.public.https.internal_http_port
    target_type                     = local.target_type[each.key]
    internal_http_health_check_path = each.value.public.https.internal_http_health_check_path
  }
}


resource "aws_lb_target_group" "container__public_https" {
  for_each = local.containers_with_public_https
  #name        = "tg-${replace(random_id.container__public_https[each.key].b64_url, "_", "-")}"
  name_prefix = replace(random_id.container__public_https[each.key].b64_url, "_", "-")
  port        = each.value.public.https.internal_http_port
  protocol    = "HTTP"
  target_type = local.target_type[each.key]
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_lb.public_http_https]
  health_check {
    path = each.value.public.https.internal_http_health_check_path
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Provose = var.name
  }
}

resource "aws_lb_listener_rule" "container__public_https" {
  for_each     = local.containers_with_public_https
  listener_arn = aws_lb_listener.public_http_https__443.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.container__public_https[each.key].arn
  }
  condition {
    host_header {
      values = each.value.public.https.public_dns_names
    }
  }
}

# Terraform has an issue where it cannot replace load balancer target groups
# with another load balancer target group having the same name.
# So whenever we change a field that forces us to create a new group, we
# generate a new random name.
resource "random_id" "container__vpc_https" {
  for_each    = local.containers_with_vpc_https
  byte_length = 4
  keepers = {
    vpc_id                          = aws_vpc.vpc.id
    internal_http_port              = each.value.vpc.https.internal_http_port
    target_type                     = local.target_type[each.key]
    internal_http_health_check_path = each.value.vpc.https.internal_http_health_check_path
  }
}


resource "aws_lb_target_group" "container__vpc_https" {
  for_each = local.containers_with_vpc_https
  #name        = "tg-${replace(random_id.container__vpc_https[each.key].b64_url, "_", "-")}"
  name_prefix = replace(random_id.container__vpc_https[each.key].b64_url, "_", "-")
  port        = each.value.vpc.https.internal_http_port
  protocol    = "HTTP"
  target_type = local.target_type[each.key]
  vpc_id      = aws_vpc.vpc.id
  depends_on = [
    aws_lb.vpc_http_https
  ]
  health_check {
    path = each.value.vpc.https.internal_http_health_check_path
  }
  tags = {
    Provose = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "container__vpc_https" {
  for_each     = local.containers_with_vpc_https
  listener_arn = aws_lb_listener.vpc_http_https__port_443.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.container__vpc_https[each.key].arn
  }
  condition {
    host_header {
      values = each.value.vpc.https.vpc_dns_names
    }
  }
}

resource "aws_ecs_service" "container" {
  for_each        = var.container
  name            = each.key
  desired_count   = each.value.instances.container_count
  launch_type     = local.launch_type[each.key]
  cluster         = aws_ecs_cluster.container[each.key].id
  task_definition = aws_ecs_task_definition.container[each.key].arn

  dynamic "load_balancer" {
    # This should only return the current container if it has an HTTPS block
    # and return an empty map if this container does not have an HTTPS block.
    for_each = {
      for name, container in { (each.key) = each.value } :
      name => container
      if can(container.public.https.internal_http_port)
    }
    content {
      target_group_arn = aws_lb_target_group.container__public_https[each.key].arn
      container_name   = aws_ecs_task_definition.container[each.key].family
      container_port   = each.value.public.https.internal_http_port
    }
  }

  dynamic "load_balancer" {
    for_each = {
      for name, container in { (each.key) = each.value } :
      name => container
      if can(container.vpc.https.internal_http_port)
    }
    content {
      target_group_arn = aws_lb_target_group.container__vpc_https[each.key].arn
      container_name   = aws_ecs_task_definition.container[each.key].family
      container_port   = each.value.vpc.https.internal_http_port
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
      security_groups  = local.ecs_service_security_groups[each.key]
      assign_public_ip = local.assign_public_ip_to_elastic_network_interface[each.key]
    }
  }

  depends_on = [
    aws_internet_gateway.vpc,
    aws_ecs_task_definition.container,
    aws_ecs_cluster.container,
    aws_lb_target_group.container__public_https
  ]

  tags = {
    Provose = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "container__instance" {
  for_each = zipmap(
    flatten([
      for container_name, launch_type in local.launch_type : [
        for i in range(var.container[container_name].instances.instance_count) :
        join("-", [container_name, "host", i])
        if ! can(var.container[container_name].instances.spot_instance)
      ]
      if launch_type == "EC2"
    ]),
    flatten([
      for container_name, launch_type in local.launch_type : [
        for i in range(var.container[container_name].instances.instance_count) :
        {
          index          = i
          container_name = container_name
          container      = var.container[container_name]
        }
        if ! can(var.container[container_name].instances.spot_instance)
      ]
      if launch_type == "EC2"
    ])
  )
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.iam__ecs_instance_profile[each.value.container_name].name
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
    aws_iam_instance_profile.iam__ecs_instance_profile,
    aws_ecs_cluster.container,
    aws_ecs_service.container
  ]

  tags = {
    Name    = each.key
    Provose = var.name
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

resource "aws_route53_record" "container__instance" {
  for_each = aws_instance.container__instance

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.internal_subdomain}"
  type    = "A"
  ttl     = "5"
  records = [each.value.private_ip]
}

data "aws_route53_zone" "external_dns__for_containers" {
  for_each     = local.container_public_root_domains
  name         = each.value
  private_zone = false
}

resource "aws_route53_record" "container__public_https" {
  for_each = { for x in local.container_public_dns_names : x => x }

  zone_id = data.aws_route53_zone.external_dns__for_containers[each.key].zone_id
  name    = each.value
  type    = "A"
  alias {
    name                   = aws_lb.public_http_https.dns_name
    zone_id                = aws_lb.public_http_https.zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "container__public_https" {
  for_each          = { for x in local.container_public_dns_names : x => x }
  domain_name       = each.value
  validation_method = "DNS"
  options {
    certificate_transparency_logging_preference = "ENABLED"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "container__public_https_validation" {
  for_each = aws_acm_certificate.container__public_https

  name       = each.value.domain_validation_options.0.resource_record_name
  type       = each.value.domain_validation_options.0.resource_record_type
  zone_id    = data.aws_route53_zone.external_dns__for_containers[each.value.domain_name].zone_id
  records    = [each.value.domain_validation_options.0.resource_record_value]
  ttl        = 60
  depends_on = [aws_acm_certificate.container__public_https]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "container__public_https_validation" {
  for_each                = aws_acm_certificate.container__public_https
  certificate_arn         = each.value.arn
  validation_record_fqdns = [aws_route53_record.container__public_https_validation[each.key].fqdn]
}

resource "aws_lb_listener_certificate" "container__public_https_validation" {
  for_each        = aws_acm_certificate_validation.container__public_https_validation
  listener_arn    = aws_lb_listener.public_http_https__443.arn
  certificate_arn = each.value.certificate_arn
}

resource "aws_route53_record" "container__vpc_https" {
  for_each = { for x in local.container_vpc_dns_names : x => x }

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = each.value
  type    = "A"
  alias {
    name                   = aws_lb.vpc_http_https.dns_name
    zone_id                = aws_lb.vpc_http_https.zone_id
    evaluate_target_health = false
  }
}

# Now we are repeating all of the aws_instance stuff, but with an aws_instance_spot_request
# instead....

resource "aws_spot_instance_request" "container__instance" {
  for_each = zipmap(
    flatten([
      for container_name, launch_type in local.launch_type : [
        for i in range(var.container[container_name].instances.instance_count) :
        join("-", [container_name, "host", i])
        if can(var.container[container_name].instances.spot_instance)
      ]
      if launch_type == "EC2"
    ]),
    flatten([
      for container_name, launch_type in local.launch_type : [
        for i in range(var.container[container_name].instances.instance_count) :
        {
          index          = i
          container_name = container_name
          container      = var.container[container_name]
        }
        if can(var.container[container_name].instances.spot_instance)
      ]
      if launch_type == "EC2"
    ])
  )
  # Special spot instance 
  wait_for_fulfillment = true
  # Below this line is `aws_instance` parameters
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.iam__ecs_instance_profile[each.value.container_name].name
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
    aws_iam_instance_profile.iam__ecs_instance_profile,
    aws_ecs_cluster.container,
    aws_ecs_service.container
  ]

  tags = {
    Name    = each.key
    Provose = var.name
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

resource "aws_route53_record" "container__instance_spot" {
  for_each = aws_spot_instance_request.container__instance

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.internal_subdomain}"
  type    = "A"
  ttl     = "5"
  records = [each.value.private_ip]
}


# == Output == 

output "container" {
  value = {
    aws_security_group = {
      container__internal_http_port = aws_security_group.container__internal_http_port
    }
    aws_ecs_cluster = {
      container = aws_ecs_cluster.container
    }
    aws_ecs_task_definition = {
      container = aws_ecs_task_definition.container
    }
    aws_lb_target_group = {
      container__public_https = aws_lb_target_group.container__public_https
      container__vpc_https    = aws_lb_target_group.container__vpc_https
    }
    aws_lb_listener_rule = {
      container__public_https = aws_lb_listener_rule.container__public_https
      container__vpc_https    = aws_lb_listener_rule.container__vpc_https
    }
    aws_ecs_service = {
      container = aws_ecs_service.container
    }
    aws_instance = {
      container__instance = aws_instance.container__instance
    }
    aws_route53_record = {
      container__instance                = aws_route53_record.container__instance
      container__public_https            = aws_route53_record.container__public_https
      container__public_https_validation = aws_route53_record.container__public_https_validation
      container__vpc_https               = aws_route53_record.container__vpc_https
      container__instance_spot           = aws_route53_record.container__instance_spot
    }
    aws_route53_zone = {
      external_dns__for_containers = data.aws_route53_zone.external_dns__for_containers
    }
    aws_acm_certificate = {
      container__public_https = aws_acm_certificate.container__public_https
    }
    aws_acm_certificate_validation = {
      container__public_https_validation = aws_acm_certificate_validation.container__public_https_validation
    }
    aws_lb_listener_certificate = {
      container__public_https_validation = aws_lb_listener_certificate.container__public_https_validation
    }
    aws_spot_instance_request = {
      container__instance = aws_spot_instance_request.container__instance
    }
  }
}
