---
title: Changelog
nav_order: 4
---

# Changelog

## v3.0.0

**TBD.**

- Updated the Terraform AWS provider to version [3.9.0](https://registry.terraform.io/providers/hashicorp/aws/3.9.0/docs). The new provider is not backwards compatible. We had to add a field in order to provision Luster clusters.
- Enabled [AWS Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html) by default for all clusters created with the [containers](../v3.0/reference/containers/) module. Users might notice a small increase in their bill due to the increased writes to AWS CloudWatch, but it should be worth it given how much easier it makes debugging containers.

## v2.0.0

**October 5, 2020.**

- Replaced the v1.x `ec2_instances` module with the brand-new (and slightly incompatible) [`ec2_on_demand_instances` module](../2.0/reference/ec2_on_demand_instances/).
- Upgraded our pin of the Terraform AWS provider version 2.54.0 to [3.0.0](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs). The new provider version is not backwards-compatible. We had to make some changes in how we verify Amazon Certificate Manager (ACM) certificates.
- Updated the following Terraform providers: [TLS to 2.2.0](https://registry.terraform.io/providers/hashicorp/tls/2.2.0/docs) and [random to 2.3.0](https://registry.terraform.io/providers/hashicorp/random/2.3.0/docs).
- You can now specify a custom user for [containers](../v2.0/reference/containers/), just like with `docker run --user`.
- Added the ability to specify arbitrary HTTPS redirects using the [`https_redirects` module](../v2.0/reference/https_redirects/). This uses an AWS Application Load Balancer to route traffic from any Route 53 zone in the AWS account to any target on the web.
- Added support for AWS FSx Lustre--Amazon Web Services' managed offering of the high-performance Lustre filesystem--in the [`lustre_file_systems` module](../v2.0/reference/lustre_file_systems/).
- Added support for AWS Elastic File Systems (EFS) by creating the [`elastic_file_systems` module](../v2.0/elastic_file_systems/) module.
- Added support for AWS Batch--via the [`batch` module](../v2.0/batch/).
- Added support for granting access to S3 buckets for EC2 On-Demand instances ([`ec2_on_demand_instances`](../v2.0/reference/ec2_on_demand_instances/)) and EC2 Spot instances ([`ec2_spot_instances`](../v2.0/reference/ec2_spot_instances/)).

## v1.1.0

**July 21, 2020.**

- Add the `internal_http_health_check_success_status_codes` parameter to the [`containers` module](../v1.1/reference/containers/).
- Added support for AWS Fargate Spot instances to the [`containers` module](../v1.1/reference/containers/).
- Specify that AWS ECS EC2 host instances should not communicate to ECS via an HTTP proxy, if the user happens to have otherwise set up a proxy on the instance.

## v1.0.2

**June 28, 2020.**

- Various minor fixes to the Provose documentation.
- We checked in an example `terraform.tf` to the root of the Provose GitHub repository, but this file was causing errors with Terraform so we subsequently removed it.

## v1.0.1

**June 22, 2020.**

- Fixed an error when computing the `for_each` values for Elastic File System mount targets.

## v1.0.0

**June 19, 2020.**

This is the initial release, so from a philosophical standpoint, there have not been any changes yet.

Despite this being marked as a 1.0 release, Provose is still alpha-quality software.
