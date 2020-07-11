---
title: Debugging
parent: Docs - v1.0 (Latest)
has_children: false
nav_order: 4
has_toc: true
---

<!-- prettier-ignore-start -->
# Debugging
{: .no_toc }
<!-- prettier-ignore-end -->

This page describes various common errors that Terraform may throw when running a Provose-based configuration and how to fix them.

If you are receiving an error message that you don't know how to fix, feel free to [file an issue](https://github.com/provose/provose/issues) on Provose's GitHub page.

<!-- prettier-ignore-start -->
## Table of contents
{: .no_toc }
<!-- prettier-ignore-end -->

<!-- prettier-ignore-start -->

1. TOC
{:toc}
<!-- prettier-ignore-end -->

## `Error putting S3 policy: OperationAborted: A conflicting conditional operation is currently in progress against this resource. Please try again.`

This error often appears when creating, deleting, or changing the security settings of an Amazon S3 bucket. It can happen for various reasons, especially if you have deleted and recreated a bucket. Try running `terraform apply` again. If the issue persists, [file an issue](https://github.com/provose/provose/issues) on Provose's GitHub page.

Provose creates Amazon S3 buckets with the [`s3_buckets`](../reference/s3_buckets) module. Provose also creates S3 buckets to store logs produced by Elastic Load Balancers provisioned by the [`containers`](../reference/containers) module.

## `Error creating IAM instance profile [...]: EntityAlreadyExists`

This error often happens when a Terraform operation that was intended to destroy an IAM instance profile was interrupted. You can find the IAM instance profile in the AWS console, but attempting to delete it from the console will not resolve the error.

Instead, you need to use the AWS CLI to delete the instance profile. Run the following command

```
aws iam delete-instance-profile --instance-profile-name <name of your instance profile>
```

and then run `terraform apply`.

## `Error: Provider configuration not present`

This may happen if you tried to delete the entire Provose module and then ran `terraform apply` or `terraform destroy`. This confuses Terraform because it does not know what to do with the now orphaned resources created by the module now that the module's existence has been wiped out.

It is easier to try and delete the resources created by your Provose module before removing the module entirely. You can read how to delete a Provose module in [Uninstalling Provose](../uninstalling/).
It is easier to try and delete the resources created by your Provose module before removing the module entirely.

### `Error deleting ECS cluster: ClusterContainsTasksException: The Cluster cannot be deleted while Tasks are active.`

This happens when you are deleting an Elastic Container Service cluster that still has tasks in it. Because Provose abstracts over ECS clusters, services, and tasks, they tend to be deleted all at the same time. However, deleting the cluster may not succeed until the tasks have finished draining. You can solve this by logging into the AWS console to stop the tasks belonging to the cluster you want to delete.
