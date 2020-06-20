---
title: Amazon Machine Images (AMIs)
nav_order: 8
---

# Provose Amazon Machine Images (AMIs)

These are Amazon Machine Images that are built for the [Provose](https://provose.com) project. Provose is a new and easy way to configure cloud infrastructure. Provose uses these images internally for launching hosts for [`aws_instance`][1], [`container`][2], and other configurations.

## Building these AMIs

These AMIs are built using [Hashicorp Packer][3], and the source code
for the AMIs can be found at [https://github.com/provose/provose-amis][4] .

### Versions

#### provose-docker-amazon-linux-2--v0.1

This is a EBS-backed, GPU-enabled, ECS-enabled Amazon Linux 2-based AMI. The parent
AMI is `amzn2-ami-ecs-gpu-hvm-2.0.20200218-x86_64-ebs`. It comes installed with Python 3 pip, Docker, Docker Compose, and the AWS CLI.

| **AWS AMI ID:** | ami-08b64fc665987971b |
| **AWS AMI source:** | 826470379119/provose-docker-amazon-linux-2--v0.1 |

[1]: /{{ site.latest_provose_version }}/reference/aws_instance.html
[2]: /{{ site.latest_provose_version }}/reference/container.html
[3]: https://packer.io/
[4]: https://github.com/provose/provose-amis
