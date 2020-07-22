---
title: ec2_instances
parent: Reference v2.0
grand_parent: Docs - v2.0 (BETA)
---

# ec2_instances

## Description

The Provose `ec2_instances` module supports the creation and deployment of Amazon EC2 instances.

## Examples

```terraform
{% include v2.0/reference/ec2_instances/main.tf %}
```

## Inputs

- `purchasing_option` -- **Required.** This value is either `"ON_DEMAND"` to request a regular "on-demand" instance or `"SPOT"` to request a much cheaper Spot instance that can be interrupted by AWS.

- `instances` -- **Required.** This object contains various meta-settings about the AWS instance.

  - `key_name` -- **Optional.** This is the name of an AWS key pair. If you include a name of a key pair here, you will be able to log into this instance using it.

  - `instance_count` -- **Optional.** The number of instances to deploy. This defaults to 1. You can set this to be more than 1 in order to create multiple instances with duplicate configuration.

  - `bash_user_data` -- **Optional.** A bash script to be passed as this instance's user data. This script is run on this instance's creation. Provose does not support Cloud-Init user data.

- `root_volume_size_gb` -- **Optional.** This is the size--in gigabytes--of the instance's root volume containing the operating system.

- `public_tcp` -- **Optional.** A list of the TCP ports on this instance that should be opened up to the public IPv4 Internet.

- `public_udp` -- **Optional.** A list of the UDP ports on this instance that should be opened up to the public IPv4 Internet.

- `internal_tcp` -- **Optional.** A list of the TCP ports on this instance that should be opened up to the rest of the VPC.

- `internal_udp` -- **Optional.** A list of the UDP ports on this instance that should be opened up to the rest of the VPC.

## Outputs

- `ec2_instances.aws_security_group.ec2_instances` -- A map with a key for every instance and every value is a Terraform [`aws_security_group`](https://www.terraform.io/docs/providers/aws/r/security_group.html) type.

- `ec2_instances.aws_instance.on_demand` -- A map with the keys as the names of the on-demand instances--dashed with a number if we set the `instances.instance_count` parameter to be greater than 1. Each value is a Terraform [`aws_instance`](https://www.terraform.io/docs/providers/aws/r/instance.html) type.

- `ec2_instances.aws_instance.spot` -- A map with the keys as the names of our spot instances--dashed with a number if we set the `instances.instance_count` parameter to be greater than 1. Each value is a Terraform [`aws_spot_instance_request`](https://www.terraform.io/docs/providers/aws/r/spot_instance_request.html).

- `ec2_instances.aws_route53_record.on_demand` -- This is a mapping from the names EC2 On-Demand instances to the [`aws_route53_record` resource](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that describes the DNS records internal to the VPC.

- `ec2_instances.aws_route53_record.spot` -- This is a mapping from the names of EC2 Spot instances to the [`aws_route53_record` resource](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that describes the DNS records internal to the VPC.

- `ec2_instances.aws_route53_record.group` -- This is a mapping from _groups_ of AWS EC2 instances to [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) describing DNS round-robin records. If you configure a group of EC2 instances by setting `instances.instance_count` to be greater than 1, then we generate a round-robin DNS record that helps load balance connections

## Implementation details

### Default AMI

Because Provose internally relies on custom bash user data configurations, it only supports
specific AMIs. This version of Provose only launches EC2 instance with the AMI
`amzn2-ami-ecs-gpu-hvm-2.0.20200218-x86_64-ebs`. This means that Provose cannot be used to
launch AWS instances with other architectures (e.g. ARM64 or 32-bit x86) or other operating
systems (e.g. Windows Server).

Provose will periodically update the AMI used as Amazon produces new AMIs, but these
will be breaking major-version upgrades of Provose that will force the destruction
and recreation of already-deployed EC2 instances.

## Provose EC2 instances are not being a load balancer.

Docker containers that are deployed using the Proovse [`containers`](../containers/) module are launched behind an Amazon Elastic Load Balancer. However, EC2 instances created with the `ec2_instances` module are not gated behind a load balancer. They are directly exposed to the VPC they are deployed in, and optionally accessible via the Internet if you specify `public_tcp` or `public_udp` ports.

## Only Bash is supported for "user data."

The phrase "user data" refers to instructions given to EC2 instances when they are created. EC2 allows user data to be supplied as shell scripts, or as the [cloud-init](https://cloudinit.readthedocs.io/en/latest/) standard for configuring instances.

Provose currently only support user data via Bash shell scripts, and does not support other shells or the cloud-init standard.
