---
title: elastic_file_systems
parent: Reference v2.0
grand_parent: Docs - v2.0 (BETA)
---

# elastic_file_systems

## Description

The Provose `elastic_file_systems` module is used to configure AWS Elastic File Systems

### Mounting a file system

Provose helps you create Elastic File Systems and makes them accessible within your Virtual Private Cloud (VPC), but you must take manual steps to mount the Elastic File Systems that you create. Read [the EFS documentation](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html) for more information.

## Examples

```terraform
{% include v2.0/reference/elastic_file_systems/main.tf %}
```

## Inputs

Currently, there are no additional inputs for creating Elastic File Systems.

## Outputs

 - `elastic_file_systems.aws_security_group.elastic_file_systems` -- The [`aws_security_group` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/security_group) that allows access to Elastic File Systems within the VPC.

 - `elastic_file_systems.aws_efs_file_system.elastic_file_systems` -- The [`aws_efs_file_system` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/efs_file_system).

 - `elastic_file_systems.aws_efs_mount_target.elastic_file_systems` -- The [`aws_efs_mount_target` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/efs_mount_target) for the filesystem. We create a mount target for every subnet in the VPC containing the Elastic File System.

 - `elastic_file_systems.aws_route53_record.elastic_file_systems` -- The [`aws_route53_record` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/route53_record) for the filesystem. EFS creates hard-to-remember DNS names, and this DNS record applies the name specified by the user.