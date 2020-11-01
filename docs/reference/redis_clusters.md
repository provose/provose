---
title: redis_clusters
parent: Reference v1.0
grand_parent: Docs - v1.0
search_exclude: true
---

# redis_clusters

## Description

The Provose `redis_clusters` module sets up a [Redis](https://redis.io/) instance using [Amazon ElastiCache for Redis](https://aws.amazon.com/elasticache/redis/).

Currently, Provose only supports setting up clusters that contain a single instance, meaning that the `instances.instance_count` parameter is not yet supported.

## Examples

```terraform
{% include_relative examples/redis_clusters/main.tf %}
```

## Inputs

- `instances` -- **Required.** This is a group of settings for the instances that run the ElastiCache cluster.

  - `instance_type` -- **Required.** This lists the ElastiCache-specific instance type to deploy. An example value is `"cache.m5.large"`. A complete list of available instance types is [here in the AWS documentation](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/CacheNodes.SupportedTypes.html).

- `engine_version` -- **Required.** This lists the Redis version to deploy--like `"5.0.6"`. A complete list of available versions is available [here in the AWS documentation](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/supported-engine-versions.html).

- `apply_immediately` -- **Optional.** This defaults to `true`, which makes configuration changes apply to the cluster immediately. When set to `false`, configuration changes are instead applied during the cluster's next maintenance window.

## Outputs

- `redis_clusters.aws_security_group.redis` -- This is a [`aws_security_group` resource](https://www.terraform.io/docs/providers/aws/r/security_group.html) that governs access to the cluster. By default, the Redis cluster is accessible within the containing VPC created by Provose.

- `redis_clusters.aws_elasticache_subnet_group.redis` -- This is the [`aws_elasticache_subnet_group` resource](https://www.terraform.io/docs/providers/aws/r/elasticache_subnet_group.html) that defines which subnets are available to the clusters. By default, this is all of the subnets in the VPC.

- `redis_clusters.aws_elasticache_cluster.redis` -- This is a mapping from cluster names to [`aws_elasticache_cluster` resources](https://www.terraform.io/docs/providers/aws/r/elasticache_cluster.html) that configure each cluster.

- `redis_clusters.aws_route53_record.redis` -- This is a mapping from cluster names to [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) representing Route 53 DNS records that give friendly names to the clusters.
