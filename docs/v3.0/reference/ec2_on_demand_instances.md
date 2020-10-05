---
title: ec2_on_demand_instances
parent: Reference v3.0
grand_parent: Docs - v3.0 (BETA)
---

# ec2_on_demand_instances

## Description

The Provose `ec2_on_demand_instances` module enables the creation and deployment of Amazon EC2 instances.

The phrase "On Demand" means these are regular ol' AWS instances that are billed at the same price per-second. This is in contrast to Spot instances--where the price can fluctuate over time--or Reserved Instances--which are partially or completely purchased upfront.

If you are looking to deploy the same application across multiple services--perhaps behind an HTTP load balancer--you might find it handier to use the [`containers` module](../containers/) instead.

## Examples

```terraform
{% include v3.0/reference/ec2_on_demand_instances/main.tf %}
```

## Inputs

- `instances` -- **Required.** This object contains various meta-settings about the AWS instance.

  - `instance_type` -- **Required.** The instance type.

  - `instance_count` -- **Optional.** The number of instances to deploy. This defaults to 1. If you deploy one instance named `bob`, then it will be named `bob` in the AWS console and Provose creates a DNS record for your internal subdomain named `bob`. If you set `instance_count` to be greater than one, then the instances will be `bob-1`, `bob-2`, and so forth.

  - `key_name` -- **Optional.** The name of the AWS key pair.

  - `ami_id` -- **Optional.** The ID of the Amazon Machine Image (AMI) to deploy for this instance. By default, Provose will deploy an ECS-optimized GPU-ready Amazon Linux 2 AMI--specifically `amzn2-ami-ecs-gpu-hvm-2.0.20200218-x86_64-ebs`. New users of Provose might want to choose a newer AMI, but Provose cannot update the default AMI for existing users without causing their existing instances to be destroyed and recreated.

  - `availability_zone` -- **Optional.** Set this to a specific Availability Zone in your AWS Region if you have a preference for what availability zone to deploy your instance in.

  - `bash_user_data` -- **Optional.** This is a [user data script](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)--a Bash script that will be run on the EC2 instance's creation. This script will not be rerun when the instance reboots. Provose currently does not support the cloud-init standard for user data.

- `public` -- **Optional.** This is a grouping for network settings for the public Internet.

  - `tcp` **Optional.** This is a list of TCP ports to open to the public Internet.

  - `udp` **Optional.** This is a list of UDP ports to open to the public Internet.

- `vpc` -- **Optional.** This is a grouping for network settings only within the Virtual Private Cloud (VPC) that Provose creates.

- `secrets` -- **Optional.** This is a _list_ of AWS Secrets Manager secret names that this EC2 instance should have access to. This setting _only_ configures access. You have to fetch the secrets yourself in your application with the AWS API. The secrets key in the [`containers` module](../containers/) goes a step further and loads your secrets as environment variables.

- `associate_public_ip_address` -- **Optional.** Defaults to `true`, which provisions a public IPv4 address for this instance. However, it will not be possible to make inbound requests to the instance using this IP address unless you also choose to open TCP ports with the `public.tcp` key or the UDP ports with the `public.udp` key. The public IP address that AWS gives this instance should be considered temporary. If you want a more permanent IP address, you should provision an Elastic IP and assign it to this instance.

- `vpc_security_group_ids` -- **Optional.** This key is for adding _additional, custom_ security groups in addition to what Provose sets up from the `public` and `vpc` keys. You may want to add a custom security group with a more specific CIDR.

- `root_block_device` -- **Optional** These are optional settings about the Elastic Block Storage (EBS) volume that stores the root filesystem for this EC2 instance.

  - `volume_type` -- **Optional.** This is the type of EBS volume. Values can be either `"standard"`, `"gp2"`, `"io1"`, `"sc1"`, or `"st1"`, with `"standard"` being the default.

  - `volume_size_gb` -- **Optional.** This is the size of the EBS volume in gigabytes. This defaults to the root volume size defined in the underlying Amazon Machine Image (AMI) and will never be less than the minimum.

  - `delete_on_termination` -- **Optional.** This defaults to `true`, which deletes the EBS volume if the instance is terminated. Set this to `false` to keep the root EBS volume in your account after instance termination.

  - `encrypted` -- **Optional.** Set this to `true` to encrypt the EBS volume. This value is `false` by default.

  - `kms_key_id` -- **Optional.** This is the Amazon Resource Name (ARN) for the custom AWS Key Management Service (KMS) key that you would like to use to encrypt the drive.

## Outputs

- `ec2_on_demand_instances.aws_security_group.ec2_on_demand_instances` -- A map with a key for every instance and every value is a Terraform [`aws_security_group`](https://www.terraform.io/docs/providers/aws/r/security_group.html) type.

- `ec2_on_demand_instances.aws_instance.ec2_on_demand_instances` -- A map with the keys as the names of the on-demand instances--dashed with a number if we set the `instances.instance_count` parameter to be greater than 1. Each value is a Terraform [`aws_instance`](https://www.terraform.io/docs/providers/aws/r/instance.html) type.

- `ec2_on_demand_instances.aws_route53_record.ec2_on_demand_instances` -- This is a mapping from the names EC2 On-Demand instances to the [`aws_route53_record` resource](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that describes the DNS records internal to the VPC.
