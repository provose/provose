---
title: postgresql_clusters
parent: Reference
grand_parent: Docs - v1.0 (Latest)
---

# postgresql_clusters

## Description

This Provose configuration sets up AWS Aurora PostgreSQL clusters.

## Examples

```terraform
{% include v1.0/reference/postgresql_clusters/two.tf %}
```

## Inputs

- `instances` -- **Required.** Settings for the AWS RDS instances running the PostgreSQL cluster.

  - `instance_type` -- **Required.** The database instance type, like `"db.r5.large"`. The accepted database instance types for AWS Aurora PostgreSQL can be found [here on the AWS website](https://aws.amazon.com/rds/aurora/pricing/?pg=pr&loc=1).

  - `instance_count` -- **Required.** The number of database instances in the cluster. Provose requires that all database instances be of the same `instance_type`.

- `engine_version` -- **Required.** This is the version of the AWS Aurora PostgreSQL cluster. The currently-supported engine versions can be found [here on the AWS website](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraPostgreSQL.Updates.20180305.html#AuroraPostgreSQL.Updates.20180305.32).

- `database_name` -- **Required.** The name of the initial database created by AWS RDS. You can create additional databases by logging into the instance with `"root"` as the username and the password you set below.

- `password` -- **Required.** The password for the database root user.

- `snapshot_identifier` -- **Optional.** If set, this is the ARN of the RDS snapshot to create this instance from. If not set, Provose provisions a blank database.

- `apply_immediately` -- **Optional** Defaults to `true`, which means that configuration changes to the database are applied immediately. If set to `false`, any changes to the database configuration made through Provose or Terraform will be applied during the database's next maintenance window. Be careful that making configuration changes can result in a database outage.

- `deletion_protection` -- **Optional.** Defaults to `true`, which is the opposite of the typical Terraform configuration. When set to `true`, the database cannot be deleted. Set to `false` if you are okay with deleting this database when running `terraform destroy` or other commands.

## Outputs

- `postgresql_clusters.aws_db_subnet_group.postgresql` -- A mapping of [`aws_db_subnet_group` resources](https://www.terraform.io/docs/providers/aws/r/db_subnet_group.html) that describe the subnets for every cluster specified. Provose defaults to setting all of the subnets available in the VPC.

- `postgresql_clusters.aws_security_group.postgresql` -- An [`aws_security_group` resource](https://www.terraform.io/docs/providers/aws/r/security_group.html) that governs access to the PostgreSQL clusters. By default, the database is open to connection from anywhere within the VPC. The database is not accessible to the public Internet.

- `postgresql_clusters.aws_rds_cluster.postgresql` -- A mapping of [`aws_rds_cluster` resources](https://www.terraform.io/docs/providers/aws/r/rds_cluster.html) for every cluster specified.

- `postgresql_clusters.aws_rds_cluster_instance.postgresql` -- A mapping of [`aws_rds_cluster_instance` resources](https://www.terraform.io/docs/providers/aws/r/rds_cluster_instance.html)--of every instance in every Aurora PostgreSQL cluster created by Provose.

- `postgresql.aws_route53_record.postgresql` -- A mapping of [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that give a friendly DNS name for every Aurora PostgreSQL cluster specified.

- `postgresql.aws_route53_record.postgresql__readonly` -- A mapping of [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that give a friendly DNS name _for the readonly endpoint_ for every Aurora postgresql cluster specified.

## Supported engine versions

You can check which versions of AWS Aurora PostgreSQl are available by running the following AWS CLI comamnd and looking for the `EngineVersion` keys:

```
aws rds describe-db-engine-versions --engine aurora-postgresql
```

Currently, the available versions are, in order from newest to oldest:

- `"11.7"`
- `"11.6"`
- `"11.4"`
- `"10.12"`
- `"10.11"`
- `"10.7"`
- `"10.7"`
- `"10.6"`
- `"10.5"`
- `"10.4"`
- `"9.6.17"`
- `"9.6.16"`
- `"9.6.12"`
- `"9.6.11"`
- `"9.6.9"`
- `"9.6.8"`
- `"9.6.6"`
- `"9.6.3"`
