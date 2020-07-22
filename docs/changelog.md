---
title: Changelog
nav_order: 4
---

# Changelog

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
