---
title: Uninstalling Provose
parent: Docs
nav_order: 5
has_children: false
has_toc: true
---

<!-- prettier-ignore-start -->
# Uninstalling Provose
{: .no_toc }
<!-- prettier-ignore-end -->

This page describes how to delete a Provose (a Terraform module) and the underlying Terraform resources it creates.

<!-- prettier-ignore-start -->
## Table of contents
{: .no_toc }
<!-- prettier-ignore-end -->

<!-- prettier-ignore-start -->

1. TOC
{:toc}
<!-- prettier-ignore-end -->

## Deleting a Provose module with `terraform destroy`

Provose is implemented as a HashiCorp Terraform module. Most Terraform resources can be deleted by removing them from the source code, but Terraform treats modules as special. Removing them from a file or deleting the entire file will cause an error.

Instead, use Terraform's selective delete feature to remove modules, including Provose. For a module named `myproject` that looks like:

```terraform
module "myproject" {
    // contents go here
}
```

run `terraform destroy -target module.myproject` to destroy all resources in the project.

## Deleting databases

If you have deployed a [MySQL](../reference/mysql_clusters/) or [PostgreSQL](../reference/postgresql_clusters/) database, you may have to disable deletion protection in order for Terraform to succeed in deleting the database. This can be done [in the AWS console](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/USER_DeleteInstance.html#USER_DeleteInstance.DeletionProtection) or it can be done by adding `deletion_protection = false` in the Provose configuration. The below example shows how to disable deletion protection on a MySQL database.

```terraform
module "myproject" {

  // ...omitted configuration here...

  mysql_clusters = {
    db1 = {
      engine_version = "5.7.mysql_aurora.2.08.0"
      database_name  = "exampledb"
      password       = "some long password"
      instances = {
        instance_type  = "db.r5.large"
        instance_count = 1
      }
      // Add this line to allow the database to be deleted.
      // If this line is omitted, deletion protection is enabled
      // and the instance cannot be deleted from Provose or
      // the AWS console.
      deletion_protection = false
    }
  }
}
```

## Deleting S3 buckets

S3 buckets can only be deleted when they are empty. Provose also automatically creates S3 buckets for storing logs from the Application Load Balancers (ALBs) used to route HTTP traffic from the Internet and from within the VPC. If you are deleting a Provose module, you should delete or empty S3 buckets created by that module through the AWS console or the AWS CLI.
