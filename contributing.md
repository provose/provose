---
title: Contributing to Provose
nav_order: 3
---

# Contributing to Provose

Provose welcomes contributions to code and documentation from the community. However, there are some ground rules.

## Your contributions owned by Neocrym Records Inc.

All of Provose's code and documentation is copyrighted by Neocrym Records Inc and licensed under the MIT license. The same must be true for your contribution. Currently, Provose does not require the signing of Contributor Licence Agreements (CLAs), but this may change in the future.

## Terraform resources are named after the file they are contained in.

For example, if we have a file named `redis_clusters.tf`, we think Terraform resources should look like

```terraform
resource "aws_security_group" "redis_clusters" {
    # content goes here
}
```

When there are multiple resources that would have conflicting names, give them different name after a double underscore.

```terraform
resource "aws_security_group" "redis_clusters__sg1" {
    # content goes here
}

resource "aws_security_group" "redis_clusters__sg2 {
    # more content goes here
}
```
