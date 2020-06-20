resource "aws_security_group" "redis_clusters" {
  count = length(var.redis_clusters) > 0 ? 1 : 0

  name                   = "P/v1/${var.provose_config.name}/redis"
  description            = "Provose security group owned by module ${var.provose_config.name}, authorizing Redis access within the VPC."
  vpc_id                 = aws_vpc.vpc.id
  revoke_rules_on_delete = true
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_elasticache_subnet_group" "redis_clusters" {
  count = length(var.redis_clusters) > 0 ? 1 : 0
  name = try(
    var.overrides.redis_clusters__aws_elasticache_subnet_group,
    "p-v1-${var.provose_config.name}-redis-sg"
  )
  subnet_ids = aws_subnet.vpc[*].id
}

resource "aws_elasticache_parameter_group" "redis_clusters" {
  for_each = var.redis_clusters
  name     = "p-v1-${var.provose_config.name}-${each.key}-redis-cluster-pg"
  family   = join("", ["redis", join(".", slice(split(".", each.value.engine_version), 0, 2))])
}

resource "aws_elasticache_cluster" "redis_clusters" {
  for_each = var.redis_clusters

  apply_immediately    = try(each.value.apply_immediately, true)
  cluster_id           = each.key
  engine               = "redis"
  node_type            = each.value.instances.instance_type
  num_cache_nodes      = 1
  engine_version       = each.value.engine_version
  security_group_ids   = [aws_security_group.redis_clusters[0].id]
  subnet_group_name    = aws_elasticache_subnet_group.redis_clusters[0].name
  parameter_group_name = aws_elasticache_parameter_group.redis_clusters[each.key].name
  port                 = 6379
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_route53_record" "redis_clusters" {
  for_each = aws_elasticache_cluster.redis_clusters

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.provose_config.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [each.value.cache_nodes.0.address]
}

# == Output ==

output "redis_clusters" {
  value = {
    aws_security_group = {
      redis_clusters = aws_security_group.redis_clusters
    }
    aws_elasticache_subnet_group = {
      redis_clusters = aws_elasticache_subnet_group.redis_clusters
    }
    aws_elasticache_cluster = {
      redis_clusters = aws_elasticache_cluster.redis_clusters
    }
    aws_route53_record = {
      redis_clusters = aws_route53_record.redis_clusters
    }
  }
}
