resource "aws_security_group" "redis" {
  count = length(var.redis) > 0 ? 1 : 0

  name_prefix = "redis-sg"
  description = "Open up the Redis to the VPC"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  tags = {
    Provose = var.name
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnets"
  subnet_ids = aws_subnet.vpc[*].id
}

resource "aws_elasticache_cluster" "redis" {
  for_each = var.redis

  apply_immediately    = try(each.value.apply_immediately, true)
  cluster_id           = each.key
  engine               = "redis"
  node_type            = each.value.instances.instance_type
  num_cache_nodes      = 1
  engine_version       = each.value.engine_version
  security_group_ids   = [aws_security_group.redis[0].id]
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  parameter_group_name = join("", ["default.redis", join(".", slice(split(".", each.value.engine_version), 0, 2))])
  port                 = 6379
  tags = {
    Provose = var.name
  }
}

resource "aws_route53_record" "redis" {
  for_each = aws_elasticache_cluster.redis

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.key}.${var.internal_subdomain}"
  type    = "CNAME"
  ttl     = "5"
  records = [each.value.cache_nodes.0.address]
}

# == Output ==

output "redis" {
  value = {
    aws_security_group = {
      redis = aws_security_group.redis
    }
    aws_elasticache_subnet_group = {
      redis = aws_elasticache_subnet_group.redis
    }
    aws_elasticache_cluster = {
      redis = aws_elasticache_cluster.redis
    }
    aws_route53_record = {
      redis = aws_route53_record.redis
    }
  }
}
