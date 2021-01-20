# Provose is the easiest way to manage your Amazon Web Service (AWS) infrastructure.

## Provose is built on top of [HashiCorp Terraform](https://www.terraform.io/), an industry-leading infrastructure-as-code tool.

Provose is a Terraform module that deploys hundreds of underlying cloud resources--containers, databases, TLS certificates, DNS rules, and more--with just a few lines of code.

## Provose is free and open-source software forever.

Provose is distributed under the MIT license. You can download Provose at [github.com/provose/provose](https://github.com/provose/provose), which is also where you can also submit bug reports and contribute improvements.

## Learn Provose from [Tutorial](https://provose.com/v1.0/tutorial/) or the [Reference](https://provose.com/v1.0/reference/).

Provose is easy to learn. You can get started with just a few lines of code.

## Subscribe to the Provose newsletter for updates

[Click here](https://provose.substack.com/) to find the Provose newsletter.

## Here is what Provose code looks like.

Below is an example of what Provose looks like, provisioning a [container serving HTTP traffic on AWS Fargate](/v3.0/reference/containers/):

```terraform
module "myproject" {
  source = "github.com/provose/provose?ref=v3.0.0"
  provose_config = {
    authentication = {
      aws = {
        region = "us-east-1"
      }
    }
    name                 = "myproject"
    # Provose requires a domain name to be used for internal purposes.
    # This allows us to protect internal services using
    # AWS Certificate Manager (ACM) certificates.
    internal_root_domain = "example-internal.com"
    internal_subdomain   = "production"
  }
  containers = {
    hello = {
      image = {
        # This is the name of a publicly-available container on DockerHub.
        # Private Elastic Container Registry (ECR) containers can also be used.
        name             = "nginxdemos/hello"
        # This is a container tag on DockerHub.
        tag              = "latest"
        private_registry = false
      }
      public = {
        https = {
          internal_http_port              = 80
          internal_http_health_check_path = "/"
          # You need to have example.com as a domain in your AWS
          # account with DNS managed by Route 53.
          # Provose will set up an Application Load Balancer serving
          # HTTP and HTTPS traffic to this group of containers.
          public_dns_names                = ["hello.example.com"]
        }
      }
      instances = {
        # Set this to an EC2 instance type to use AWS ECS-EC2
        # or FARGATE_SPOT to automatically save money by using Spot
        # instances.
        instance_type   = "FARGATE"
        container_count = 1
        cpu             = 256
        memory          = 512
      }
    }
  }
}


```

You can also take a look at how to use Provose to provision [MySQL](https://provose.com/v1.0/reference/mysql_clusters/), [PostgreSQL](https://provose.com/v1.0/reference/postgresql_clusters/), [Elasticsearch](https://provose.com/v1.0/reference/elasticsearch_clusters/), [Redis](https://provose.com/v1.0/reference/redis_clusters/), and [Elastic Container Service](https://provose.com/v1.0/reference/containers/) clusters _and a lot more_ on Amazon Web Services.

## How to report a security issue

**To report a security issue, email security@neocrym.com. Do not post on GitHub.**

## Dependencies

Provose is a [HashiCorp Terraform module](https://www.terraform.io/), and needs the [latest version of Terraform installed](https://learn.hashicorp.com/terraform/getting-started/install.html) on your machine to run.

Additionally, Provose also depends on the [AWS CLI version 2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) to run additional configuration commands not yet supported in Terraform.

If you want to build and deploy Docker images with Provose, you will also need the [`docker` command](https://docs.docker.com/engine/install/) installed on your machine.

## Installation

Follow the [Tutorial](https://provose.com/v1.0/tutorial/) for instructions on how to install and use Provose.
