---
# Feel free to add content and custom Front Matter to this file.
# To modify the layout, see https://jekyllrb.com/docs/themes/#overriding-theme-defaults

layout: home
title: Home
nav_order: 1
---

# Provose is the easiest way to manage your Amazon Web Services infrastructure.

## Provose is built on top of [HashiCorp Terraform](https://www.terraform.io/), an industry-leading infrastructure-as-code tool.

Provose is a Terraform module that deploys hundreds of underlying cloud resources--containers, databases, TLS certificates, DNS rules, and more--with just a few lines of code.

## Provose is free and open-source software forever.

Provose is distributed under the MIT license. You can download Provose at [github.com/provose/provose](https://github.com/provose/provose), which is also where you can also submit bug reports and contribute improvements.

## Learn Provose from [Tutorial](/v1.0/tutorial/) or the [Reference](/v1.0/reference/).

Provose is easy to learn. You can get started with just a few lines of code.

## Sign up for the Provose newsletter for release announcements and occasional tips.

Don't worry, we won't email you too often.

<iframe src="https://provose.substack.com/embed" width="480" height="320" style="border:1px solid #EEE; background:white;" frameborder="0" scrolling="no"></iframe>

## Here is what Provose code looks like.

Below is an example of what Provose looks like, provisioning
[a single AWS EC2 instance](/v1.0/reference/aws_instance.html):

```terraform
{% include homepage_snippet.tf %}
```

You can also take a look at how to use Provose to provision [MySQL](/v1.0/reference/mysql_clusters/), [PostgreSQL](/v1.0/reference/postgresql_clusters/), [Elasticsearch](/v1.0/reference/elasticsearch_clusters/), [Redis](/v1.0/reference/redis_clusters/), and [Elastic Container Service](/v1.0/reference/containers/) clusters and _a lot more_ on Amazon Web Services.
