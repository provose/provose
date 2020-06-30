---
title: mysql_clusters
parent: Reference
grand_parent: Docs - v1.0 (Latest)
---

# mysql_clusters

## Description

This Provose configuration sets up AWS Aurora MySQL database clusters.

## Examples

```terraform
{% include v1.0/reference/mysql_clusters/two.tf %}
```

## Inputs

- `instances` -- **Required.** Settings for the AWS RDS instances running the MySQL cluster.

  - `instance_type` -- **Required.** The database instance type, like `"db.r5.large"`. The accepted database instance types for AWS Aurora MySQL can be found [here on the AWS website](https://aws.amazon.com/rds/aurora/pricing/?pg=pr&loc=1).

  - `instance_count` -- **Required.** The number of database instances in the cluster. Provose requires that all database instances be of the same `instance_type`.

- `engine_version` -- **Required.** This is the version of the AWS Aurora MySQL cluster. [See below](#supported-engine-versions) to see the supported engine versions for AWS Aurora MySQL.

- `database_name` -- **Required.** The name of the initial database created by AWS RDS. You can create additional databases by logging into the instance with `"root"` as the username and the password you set below.

- `password` -- **Required.** The password for the database root user.

- `snapshot_identifier` -- **Optional.** If set, this is the ARN of the RDS snapshot to create this instance from. If not set, Provose provisions a blank database.

- `apply_immediately` -- **Optional** Defaults to `true`, which means that changes to the database are applied immediately. If set to `false`, any changes to the database configuration made through Provose or Terraform will be applied during the database's next maintenance window. Be careful that making configuration changes can result in a database outage.

- `deletion_protection` -- **Optional.** Defaults to `true`, which is the opposite of the typical Terraform configuration. When set to `true`, the database cannot be deleted. Set to `false` if you are okay with deleting this database when running `terraform destroy` or other commands.

## Outputs

- `mysql_clusters.aws_db_subnet_group.mysql` -- A mapping of [`aws_db_subnet_group` resources](https://www.terraform.io/docs/providers/aws/r/db_subnet_group.html) that describe the subnets for every cluster specified. Provose defaults to setting all of the subnets available in the VPC.

- `mysql_clusters.aws_security_group.mysql` -- An [`aws_security_group` resource](https://www.terraform.io/docs/providers/aws/r/security_group.html) that governs access to the MySQL clusters. By default, the database is open to connection from anywhere within the VPC. The database is not accessible to the public Internet.

- `mysql_clusters.aws_rds_cluster.mysql` -- A mapping of [`aws_rds_cluster` resources](https://www.terraform.io/docs/providers/aws/r/rds_cluster.html) for every cluster specified.

- `mysql_clusters.aws_rds_cluster_instance.mysql` -- A mapping of [`aws_rds_cluster_instance` resources](https://www.terraform.io/docs/providers/aws/r/rds_cluster_instance.html)--of every instance in every Aurora MySQl cluster created by Provose.

- `mysql.aws_route53_record.mysql` -- A mapping of [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that give a friendly DNS name for every Aurora MySQL cluster specified.

- `mysql.aws_route53_record.mysql__readonly` -- A mapping of [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that give a friendly DNS name _for the readonly endpoint_ for every Aurora MySQL cluster specified.

## Supported engine versions

You can check which versions of AWS Aurora MySQL are available by running the following AWS CLI command and looking for the `EngineVersion` keys:

```
aws rds describe-db-engine-versions --engine aurora-mysql
```

Currently, the available versions are, in order from newest to oldest:

- `"5.7.mysql_aurora.2.08.0"`
- `"5.7.mysql_aurora.2.07.2"`
- `"5.7.mysql_aurora.2.07.1"`
- `"5.7.mysql_aurora.2.07.0"`
- `"5.7.mysql_aurora.2.06.0"`
- `"5.7.mysql_aurora.2.05.0"`
- `"5.7.mysql_aurora.2.04.8"`
- `"5.7.mysql_aurora.2.04.7"`
- `"5.7.mysql_aurora.2.04.6"`
- `"5.7.mysql_aurora.2.04.5"`
- `"5.7.mysql_aurora.2.04.4"`
- `"5.7.mysql_aurora.2.04.3"`
- `"5.7.mysql_aurora.2.04.2"`
- `"5.7.mysql_aurora.2.04.1"`
- `"5.7.mysql_aurora.2.04.0"`
- `"5.7.mysql_aurora.2.03.4"`
- `"5.7.mysql_aurora.2.03.3"`
- `"5.7.mysql_aurora.2.03.2"`
- `"5.7.12"`

After version `"5.7.12"`, AWS changed Aurora MySQL engine versioning to be in the format `[compatible mysql version].mysql_aurora.[aurora version]`.
