# This resource generates a random suffix to the
# AWS RDS final snapshot identifier.
# This is to avoid name conflicts when the same database is created
# and destroyed twice.
resource "random_string" "postgresql_clusters__final_snapshot_id" {
  for_each = var.postgresql_clusters
  keepers = {
    provose_config__name                                = var.provose_config.name
    cluster_name                                        = each.key
    engine_version                                      = each.value.engine_version
    overrides__postgresql_clusters__aws_db_subnet_group = try(var.overrides.postgresql_clusters__aws_db_subnet_group, "")
  }
  # AWS RDS final snapshot identifiers are stored in lowercase, so
  # uppercase characters would not add additional entropy.
  upper = false
  # Final snapshot identifiers also do not support special characters,
  # except for hyphens. It is also forbidden to end the identifier
  # with a hyphen or to use two consecutive hyphens, so we avoid special
  # characters all together.
  special = false
  length  = 20
}

resource "aws_security_group" "postgresql_clusters" {
  count = length(var.postgresql_clusters) > 0 ? 1 : 0

  name                   = "P/v1/${var.provose_config.name}/postgresql"
  description            = "Provose security group owned by module ${var.provose_config.name}, authorizing PostgreSQL access within the VPC."
  vpc_id                 = aws_vpc.vpc.id
  revoke_rules_on_delete = true
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_db_subnet_group" "postgresql_clusters" {
  count = length(var.postgresql_clusters) > 0 ? 1 : 0

  name = try(
    var.overrides.postgresql_clusters__aws_db_subnet_group,
    "p-v1-${var.provose_config.name}-postgresql-sg"
  )
  subnet_ids = aws_subnet.vpc[*].id
}

locals {
  # Here we determine the parameter group family based on the engine version.
  # Currently the only available parameter group families for AWS Aurora PostgreSQl
  # are "aurora-postgresql9.6", "aurora-postgresql10", and "aurora-postgresql11"
  postgresql_clusters__parameter_group_family = {
    for key, config in var.postgresql_clusters :
    key => length(regexall("^9\\.6", config.engine_version)) > 0 ? "aurora-postgresql9.6" : (length(regexall("^10", config.engine_version)) > 0 ? "aurora-postgresql10" : regex("^11", config.engine_version) == "11" ? "aurora-postgresql11" : "error")
  }
}

resource "aws_rds_cluster_parameter_group" "postgresql_clusters" {
  for_each    = var.postgresql_clusters
  name        = "p-v1-${var.provose_config.name}-${each.key}-postgresql-cluster-pg"
  family      = local.postgresql_clusters__parameter_group_family[each.key]
  description = "Provose cluster parameter group for AWS Aurora PostgreSQL, for module ${var.provose_config.name} and cluster ${each.key}"
}

resource "aws_db_parameter_group" "postgresql_clusters" {
  for_each    = var.postgresql_clusters
  name        = "p-v1-${var.provose_config.name}-${each.key}-postgresql-db-pg"
  family      = local.postgresql_clusters__parameter_group_family[each.key]
  description = "Provose database parameter group for AWS Aurora PostgreSQL, for module ${var.provose_config.name} and cluster ${each.key}"
  parameter {
    name         = "max_connections"
    value        = 5000
    apply_method = "pending-reboot"
  }
}

resource "aws_rds_cluster" "postgresql_clusters" {
  for_each = var.postgresql_clusters

  apply_immediately               = try(each.value.apply_immediately, true)
  engine                          = "aurora-postgresql"
  engine_mode                     = "provisioned"
  cluster_identifier              = each.key
  master_username                 = try(each.value.username, "root")
  master_password                 = each.value.password
  vpc_security_group_ids          = [aws_security_group.postgresql_clusters[0].id]
  engine_version                  = each.value.engine_version
  db_subnet_group_name            = aws_db_subnet_group.postgresql_clusters[0].name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.postgresql_clusters[each.key].name
  database_name                   = each.value.database_name
  snapshot_identifier             = try(each.value.snapshot_identifier, null)
  deletion_protection             = try(each.value.deletion_protection, true)
  copy_tags_to_snapshot           = true
  # We generate final snapshot identifiers with random names so that there
  # are no conflicts when the user creates a database, destroys it (creating the
  # final snapshot), and then tries to create and destroy the database again.
  # The snapshot identifier is also not allowed to have two consecutive hyphens
  # so we make sure to remove that from the database name.
  # The final snapshot name must be a maxiumum of 255 characters.
  final_snapshot_identifier = "p-v1-${replace(var.provose_config.name, "--", "-")}-postgresql-fs-${random_string.postgresql_clusters__final_snapshot_id[each.key].result}"
  skip_final_snapshot       = false
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_rds_cluster_instance" "postgresql_clusters" {
  for_each = zipmap(
    flatten([
      for key, value in var.postgresql_clusters : [
        for i in range(value.instances.instance_count) :
        join("-", [key, i])
      ]
    ]),
    flatten([
      for key, value in var.postgresql_clusters : [
        for i in range(value.instances.instance_count) :
        {
          key                = key
          cluster_identifier = aws_rds_cluster.postgresql_clusters[key].id
          instance_type      = value.instances.instance_type
          apply_immediately  = try(value.apply_immediately, true)
        }
      ]
    ])
  )
  apply_immediately            = each.value.apply_immediately
  engine                       = "aurora-postgresql"
  identifier                   = each.key
  cluster_identifier           = each.value.cluster_identifier
  instance_class               = each.value.instance_type
  db_subnet_group_name         = aws_db_subnet_group.postgresql_clusters[0].name
  db_parameter_group_name      = aws_db_parameter_group.postgresql_clusters[each.value.key].name
  performance_insights_enabled = true

  depends_on = [aws_rds_cluster.postgresql_clusters]
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_route53_record" "postgresql_clusters" {
  for_each = aws_rds_cluster.postgresql_clusters

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.provose_config.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [each.value.endpoint]
}

resource "aws_route53_record" "postgresql_clusters__readonly" {
  for_each = aws_rds_cluster.postgresql_clusters

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}-readonly.${var.provose_config.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [each.value.reader_endpoint]
}

# == Output ==

output "postgresql_clusters" {
  value = {
    aws_db_subnet_group = {
      postgresql_clusters = aws_db_subnet_group.postgresql_clusters
    }
    aws_security_group = {
      postgresql_clusters = aws_security_group.postgresql_clusters
    }
    aws_rds_cluster = {
      postgresql_clusters = aws_rds_cluster.postgresql_clusters
    }
    aws_rds_cluster_instance = {
      postgresql_clusters = aws_rds_cluster_instance.postgresql_clusters
    }
    aws_route53_record = {
      postgresql_clusters           = aws_route53_record.postgresql_clusters
      postgresql_clusters__readonly = aws_route53_record.postgresql_clusters__readonly
    }
  }
}
