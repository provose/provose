resource "aws_db_subnet_group" "postgresql" {
  count = length(var.postgresql) > 0 ? 1 : 0

  name       = "postgresql-subnets"
  subnet_ids = aws_subnet.vpc[*].id
}

resource "aws_security_group" "postgresql" {
  count = length(var.postgresql) > 0 ? 1 : 0

  name_prefix = "${var.name}/postgresql"
  description = "Provose security group owned by module ${var.name}, authorizing PostgreSQL access within the VPC."
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  tags = {
    Provose = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_rds_cluster" "postgresql" {
  for_each = var.postgresql

  apply_immediately         = try(each.value.apply_immediately, true)
  engine                    = "aurora-postgresql"
  engine_mode               = "provisioned"
  cluster_identifier        = each.key
  master_username           = try(each.value.username, "root")
  master_password           = each.value.password
  vpc_security_group_ids    = [aws_security_group.postgresql[0].id]
  engine_version            = each.value.engine_version
  db_subnet_group_name      = aws_db_subnet_group.postgresql[0].name
  database_name             = each.value.database_name
  final_snapshot_identifier = "${var.name}-postgresql-final-snapshot"
  tags = {
    Provose = var.name
  }
}

resource "aws_rds_cluster_instance" "postgresql" {
  for_each = zipmap(
    flatten([
      for key, value in var.postgresql : [
        for i in range(value.instances.count) :
        join("-", [key, i])
      ]
    ]),
    flatten([
      for key, value in var.postgresql : [
        for i in range(value.instances.count) :
        {
          cluster_identifier = aws_rds_cluster.postgresql[key].id
          instance_type      = value.instances.instance_type
          apply_immediately  = try(value.apply_immediately, true)
        }
      ]
    ])
  )
  apply_immediately    = each.value.apply_immediately
  engine               = "aurora-postgresql"
  identifier           = each.key
  cluster_identifier   = each.value.cluster_identifier
  instance_class       = each.value.instance_type
  db_subnet_group_name = aws_db_subnet_group.postgresql[0].name

  depends_on = [aws_rds_cluster.postgresql]
  tags = {
    Provose = var.name
  }
}

resource "aws_route53_record" "postgresql" {
  for_each = var.postgresql

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [aws_rds_cluster.postgresql[each.key].endpoint]
}

resource "aws_route53_record" "postgresql__readonly" {
  for_each = var.postgresql

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}-readonly.${var.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [aws_rds_cluster.postgresql[each.key].reader_endpoint]
}

# == Output ==

output "postgresql" {
  value = {
    aws_db_subnet_group = {
      postgresql = aws_db_subnet_group.postgresql
    }
    aws_security_group = {
      postgresql = aws_security_group.postgresql
    }
    aws_rds_cluster = {
      postgresql = aws_rds_cluster.postgresql
    }
    aws_rds_cluster_instance = {
      postgresql = aws_rds_cluster_instance.postgresql
    }
    aws_route53_record = {
      postgresql           = aws_route53_record.postgresql
      postgresql__readonly = aws_route53_record.postgresql__readonly
    }
  }
}
