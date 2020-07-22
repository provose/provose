---
title: overrides
parent: Reference v2.0
grand_parent: Docs - v2.0 (BETA)
---

# overrides

## Description

The `overrides` module exists for specific settings that are often used to maintain backwards-compatibility with older versions of Provose. They should not be used in newer versions of Provose.

Sometimes a new version of Provose changes the name of a Terraform resource, which often requires that resource to be destroyed and recreated when upgrading to the newer version of Provose. This recreation may cause data loss, so to prevent it, an override key can be set to retain the old name.

## Examples

```terraform
{% include v2.0/reference/overrides/main.tf %}
```

## Inputs

- `mysql_clusters__aws_db_subnet_group` -- Sets the name for the MySQL database subnet group. This name must be unique within the AWS account. No other database subnet group must have this name.

* `postgresql_clusters__aws_db_subnet_group` -- Sets the name for the PostgreSQL database subnet group. This name must be unique within the AWS account. No other database subnet group must have this name.

* `redis_clusters__aws_elasticache_subnet_group` -- Sets the name for the ElastiCache Redis subnet group. This name must be unique within the AWS account. No other Redis cluster subnet group must have this name.

## Outputs

There are no Terraform outputs for the `overrides` module. This is purely for setting configurations.
