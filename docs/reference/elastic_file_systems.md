---
title: elastic_file_systems
parent: Reference v3.0
grand_parent: Docs - v3.0 (BETA)
---

# elastic_file_systems

## Description

The Provose `elastic_file_systems` module is used to configure AWS Elastic File Systems

### Mounting a file system

Provose helps you create Elastic File Systems and makes them accessible within your Virtual Private Cloud (VPC), but you must take manual steps to mount the Elastic File Systems that you create. Read [the EFS documentation](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html) for more information.

## Examples

### The simplest example

This creates an unencrypted filesystem, defaulting to `"bursting"` as the throughput mode and with the performance mode being `"generalPurpose"`.

```terraform
{% include v3.0/reference/elastic_file_systems/main.tf %}
```

## Inputs

Currently, there are no additional inputs for creating Elastic File Systems.

Currently, there are no _required_ parameters for creating Elastic File Systems. Below are optional parameters for tuning performance or security. Beware that changing any of these parameters for an already-existing filesystem may cause Terraform to delete and recreate your filesystem.

- `performance_mode` -- **Optional.** This is the performance mode for the filesystem. This defaults to the value `"generalPurpose"` but can be set to `"maxIO"` for better performance.

- `throughput_mode` -- **Optional.** This sets the throughput mode for the filesytem. The default value is `"bursting"` which provides additional IOPS for this filesystem in bursts. To provision IOPS for this filesystem, set it to `"provisioned"`.

- `provisioned_throughput_in_mib_per_second` -- **Optional.** When the `throughput_mode` is set to `"provisioned"`, use this input to set how much throughput to provision in mebibytes per second.

- `encrypted` -- **Optional.** Set to `true` to encrypt the filesystem at rest. The default is `false`.

- `kms_key_id` -- **Optional.** The ID for the AWS Key Management System key used to encrypt the filesystem. Only use this parameter when you are setting `encrypted` to `true`.

## Outputs

- `elastic_file_systems.aws_security_group.elastic_file_systems` -- The [`aws_security_group` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/security_group) that allows access to Elastic File Systems within the VPC.

- `elastic_file_systems.aws_efs_file_system.elastic_file_systems` -- The [`aws_efs_file_system` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/efs_file_system).

- `elastic_file_systems.aws_efs_mount_target.elastic_file_systems` -- The [`aws_efs_mount_target` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/efs_mount_target) for the filesystem. We create a mount target for every subnet in the VPC containing the Elastic File System.

- `elastic_file_systems.aws_route53_record.elastic_file_systems` -- The [`aws_route53_record` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/route53_record) for the filesystem. EFS creates hard-to-remember DNS names, and this DNS record applies the name specified by the user.
