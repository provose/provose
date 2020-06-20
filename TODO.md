# TODO

## Sub-modules

Create separate Terraform sub-modules to create AWS Security Groups, IAM roles, and Load Balancer Targer Groups. We could do this now, but this will be a lot easier to do after Terraform 0.13 is released and has support for `count` and `for_each` [for modules][1].

[1]: https://github.com/hashicorp/terraform/issues/17519
