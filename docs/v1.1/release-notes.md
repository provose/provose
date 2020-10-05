---
title: Release notes
parent: Docs - v1.1
nav_order: 1
---

# Provose v1.1 Release notes

This is the initial public version of Provose, after being incubated for several months at [Neocrym](https://neocrym.com).

The v1.1 release is focused on providing the [containers](../reference/containers/) module as simple abstraction over Elastic Container Service, and also offers simple abstractions for resources that containers depend on--like [ECR image registries](../reference/images/), [secrets](../reference/secrets/), [S3 buckets](../reference/s3_buckets/), databases (including [MySQL](../reference/mysql_clusters/), [PostgreSQL](../reference/postgresql_clusters/), [Elasticsearch](../reference/elasticsearch_clusters/) and [Redis](../reference/redis_clusters/)), and more.

Neocrym runs their nearly all of their AWS infrastructure--which includes a sizable web crawling and machine learning operation--on Provose, but Provose should still be considered alpha-quality software. Be careful when running `terraform apply` operations that could delete resources, and be careful when updating Provose.
