---
title: Security
nav_order: 6
---

# Security

## How to report a security issue

**To report a security issue, email [security@neocrym.com](mailto:security@neocrym.com). Do not post on GitHub.**

## Provose's threat model

### Provose keeps sensitive information in Terraform state.

Terraform synchronizes its operations by storing ["state"](https://www.terraform.io/docs/state/index.html) about what has been deployed. By default, the state is written to the local filesystem, but Terraform also makes it easy to [store state remotely](https://www.terraform.io/docs/state/remote.html)--such as in an Amazon S3 bucket. This allows multiple contributors to run Terraform on different machines while only keeping one synchronized copy of state.

Other Terraform modules avoid writing sensitive information to Terraform state, instead writing sensitive information to the local filesystem. However, this makes it more difficult to synchronize Terraform on multiple machines.

Provose assumes that your Terraform state is secure. We recommend storing state in an encrypted, versioned Amazon S3 bucket that can only be accessed by the AWS accounts that need to run Terraform.

### Provose believes in trusted VPCs.

Many organizations structure their cloud infrastructure with the principle of [defense-in-depth](<https://en.wikipedia.org/wiki/Defense_in_depth_(computing)>). However, Provose creates VPCs and provisions resources in them with network access open to other resources within the VPC. Provose makes the assumption that resources deployed within the same VPC can trust each other, and that defense-in-depth should be practiced by deploying unrelated resources in separate, unpeered VPCs.

### Provose recommends using AWS credentials that cannot destroy resources.

Provose and Terraform have some superficial protection of important resources, like enabling [deletion protection](https://aws.amazon.com/about-aws/whats-new/2018/09/amazon-rds-now-provides-database-deletion-protection/) by default on AWS Relational Database Service (RDS) databases.
