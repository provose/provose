resource "aws_db_subnet_group" "mysql" {
  count = length(var.mysql) > 0 ? 1 : 0

  name       = "mysql-subnets"
  subnet_ids = aws_subnet.vpc[*].id
}

resource "aws_security_group" "mysql" {
  count = length(var.mysql) > 0 ? 1 : 0

  name        = "${var.name}/mysql"
  description = "Provose security group owned by module ${var.name}, authorizing MySQL access within the VPC."
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 3306
    to_port     = 3306
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

resource "aws_rds_cluster" "mysql" {
  for_each = var.mysql

  apply_immediately         = try(each.value.apply_immediately, true)
  engine                    = "aurora-mysql"
  engine_mode               = "provisioned"
  cluster_identifier        = each.key
  master_username           = try(each.value.username, "root")
  master_password           = each.value.password
  vpc_security_group_ids    = [aws_security_group.mysql[0].id]
  engine_version            = each.value.engine_version
  db_subnet_group_name      = aws_db_subnet_group.mysql[0].name
  database_name             = each.value.database_name
  final_snapshot_identifier = "${var.name}-mysql-final-snapshot"
  tags = {
    Provose = var.name
  }
}

resource "aws_rds_cluster_instance" "mysql" {
  for_each = zipmap(
    flatten([
      for key, value in var.mysql : [
        for i in range(value.instances.count) :
        join("-", [key, i])
      ]
    ]),
    flatten([
      for key, value in var.mysql : [
        for i in range(value.instances.count) :
        {
          cluster_identifier = aws_rds_cluster.mysql[key].id
          instance_type      = value.instances.instance_type
          apply_immediately  = try(value.apply_immediately, true)
        }
      ]
    ])
  )
  apply_immediately    = each.value.apply_immediately
  engine               = "aurora-mysql"
  identifier           = each.key
  cluster_identifier   = each.value.cluster_identifier
  instance_class       = each.value.instance_type
  db_subnet_group_name = aws_db_subnet_group.mysql[0].name

  depends_on = [aws_rds_cluster.mysql]
  tags = {
    Provose = var.name
  }
}

resource "aws_route53_record" "mysql" {
  for_each = var.mysql

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [aws_rds_cluster.mysql[each.key].endpoint]
}

resource "aws_route53_record" "mysql__readonly" {
  for_each = var.mysql

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}-readonly.${var.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [aws_rds_cluster.mysql[each.key].reader_endpoint]
}

# == Output == 

output "mysql" {
  value = {
    aws_db_subnet_group = {
      mysql = aws_db_subnet_group.mysql
    }
    aws_security_group = {
      mysql = aws_security_group.mysql
    }
    aws_rds_cluster = {
      mysql = aws_rds_cluster.mysql
    }
    aws_rds_cluster_instance = {
      mysql = aws_rds_cluster_instance.mysql
    }
    aws_route53_record = {
      mysql           = aws_route53_record.mysql
      mysql__readonly = aws_route53_record.mysql__readonly
    }
  }
}
