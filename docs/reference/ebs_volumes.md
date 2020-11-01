---
# TODO: Create an example that shows both creating an EBS volume and mounting
# it with the ec2_instances module.
title: ebs_volumes
#parent: Reference v1.0
#grand_parent: Docs - v1.0
search_exclude: true
nav_exclude: true
---

# ebs_volumes

## Description

The Provose `ebs_volumes` module configures Elastic Block Storage (EBS) volumes that exist independently of any EC2 instance or ECS container.

[Containers](../containers/) and [EC2 instances](../ec2_instances/) come with their own root volumes, but those volumes will not persist of the container or instance are destroyed and recreated. The `ebs_volumes` module is a great way to set up filesystems that will continue to exist even when the EC2 instance mounting the filesystem is destroyed.

## Examples

### Creating two EBS volumes in different availability zones.

```terraform
{% include_relative examples/ebs_volumes/main.tf %}
```

## Inputs

- `availability_zone` -- **Required.** The AWS availability zone to place the EBS volume. Keep in mind that the EC2 instance that mounts this EBS volume must be in the same availability zone.

- `size_gb` -- **Required.** The size of the EBS volume in gigabytes.

- `type` -- **Optional.** The type of the EBS volume. This defaults to `"gp2"`, but can also be `"standard"`, `"io1"`, `"sc1"`, or `"st1"`. The AWS documentation describes in detail what the [different EBS volume types mean](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html).

- `iops` -- **Optional.** The number of [I/O Operations Per Second (IOS)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-io-characteristics.html) to provision for the disk.

- `encrypted` -- **Optional.** Defaults to `false.` If set to `true`, this enables encryption at rest for the EBS volume.

- `kms_key_id` -- **Optional.** The Amazon Resource Name (ARN) for an AWS Key Management Service (KMS) key to use when `encrypted` is set to `true`.

## Outputs

- `ebs_volumes.aws_ebs_volume.ebs_volume` -- This is the underlying [`aws_ebs_volume` resource](https://www.terraform.io/docs/providers/aws/r/ebs_volume.html).
