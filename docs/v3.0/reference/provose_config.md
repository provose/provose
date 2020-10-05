---
title: provose_config
parent: Reference v3.0
grand_parent: Docs - v3.0 (BETA)
---

# provose_config

## Description

The `provose_config` module is used to describe settings that are required by all of the other Provose modules.

### Authentication

Provose connects to your Amazon Web Services account using both the Terraform AWS provider and the AWS CLI v2--which must be installed on the machine running Provose. Both the provider and the CLI will look for credentials in these places in the following order:

1. The `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
2. Credentials under the `"default"` profile in the `~/.aws/credentials` file on your system. You can select a different profile with the `AWS_PROFILE` environment variable.
3. Credentials under the `"default"` profile in the `~/.aws/config` file on your system. You can select a different profile with the `AWS_PROFILE` environment variable.
4. Container credentials, if you happen to be running Provose inside of a container you deployed to Amazon Elastic Container Service (ECS).
5. Instance profile credentials, if you happen to be running Provose inside of an Amazon EC2 instance.

For #2 or #3, you would install your credentials in an appropriate file and then run `AWS_PROFILE=name-of-your-profile terraform plan` (or `terraform apply` or `terraform destroy`). Amazon [[has a guide for setting up the `credentials` and `config` files](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).

## Examples

```terraform
{% include v3.0/reference/provose_config/main.tf %}
```

## Inputs

- `authentication` -- **Required.** This is an object that contains the authentication information needed for Provose's underlying Terraform providers.

  - `aws` -- **Required.** This object contains information for connecting to AWS resources.

    - `region` -- **Required.** This is the AWS region for Provose to connect to.

    - `access_key` -- **Optional.** This is the AWS IAM access key. If you omit this, Terraform will look in your AWS config and environment variable for credentials. If you are running Terraform on an AWS EC2 instance, you can omit the `access_key` key to use the EC2 instance's IAM instance profile.

    - `secret_key` -- **Optional.** This is the AWS IAM access key. If you omit this, Terraform will look in your AWS config and environment variable for credentials. If you are running Terraform on an AWS EC2 instance, you can omit the `access_key` key to use the EC2 instance's IAM instance profile.

- `name` -- **Required.** This is the "name" for this instance of Provose. This is the namespace for the underlying Terraform resources that Provose deploys, which lets you use the Provose module multiple times without creating conflicts in name resources.

- `internal_root_domain` -- **Required.** This is the domain name that you are using with Provose. Provose requires you to have a domain name in your AWS account as the base name for TLS certificates that Provose provisions. These certificates are used to secure access to internal services.

- `internal_subdomain` -- **Required.** This is the subdomain used for **this** instance of Provose. Give a different internal subdomain to every Provose module to prevent name conflicts.

- `vpc_cidr` -- **Optional.** This is the CIDR that specifies how many addresses to allocate in the VPC and what format they are. This is an optional parameter that defaults to `"10.0.0.0/16"`. If you are setting up multiple Provose modules that can connect to each other with VPC peering, you will want to set non-overlapping CIDRs for the two modules.

## Outputs

This Provose configuration creates no resources by itself. It helps configure all of the other resources.
