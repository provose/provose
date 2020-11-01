---
title: Tutorial
parent: Docs
search_exclude: true
nav_order: 2
---

<!-- prettier-ignore-start -->
# Provose v1.0 Tutorial
{: .no_toc }
<!-- prettier-ignore-end -->

This is a tutorial aimed at teaching the beginner how to use Provose. It helps to be familiar with Amazon Web Services and HashiCorp Terraform, but this tutorial tries to give you the knowledge you need as you go.

If you have ideas on improving this tutorial, please [file an issue](https://github.com/provose/provose/issues) on Provose's GitHub page.

<!-- prettier-ignore-start -->
## Table of contents
{: .no_toc }
<!-- prettier-ignore-end -->

<!-- prettier-ignore-start -->

1. TOC
{:toc}
<!-- prettier-ignore-end -->

## Buy or move a domain name in your AWS account

Provose requires that you have a top-level domain name in your AWS account that will be delegated to serving internal services.

This domain name will be used as the base DNS name for EC2 instances, load balancers, databases, and other services that are **not** exposed to the public internet. However, Provose needs this to be a real, registered public domain name so that Provose can register Amazon Certificate Manager security certificates with it.

If your company's main website is served on `example.com`, you should purchase another domain, such as `example-internal.com` for Provose. This domain name may host a few publicly-accessible instances, such as SSH "bastion" hosts or VPN endpoints, but mostly will only be used to route network requests within Virtual Private Clouds (VPCs) that Provose creates.

Amazon has a guide for [registering a new domain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html) and another one for [transferring a domain registered elsewhere into your AWS account](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-transfer-to-route-53.html).

## Install Provose's prerequisites

Whether you are running Provose on your local machine, an EC2 instance, or a Continuous Integration (CI) provider, you will need to make sure that the machine has the following dependencies installed:

### HashiCorp Terraform

Provose is built on top of HashiCorp Terraform, and industry-leading infrastructure-as-code tool.

Terraform's documentation describes how to [download and install](https://learn.hashicorp.com/terraform/getting-started/install.html) the latest version of Terraform for your operating system.

### AWS CLI v2

There are some configurations on AWS that Terraform's AWS provider does not currently support. Provose works around these limitations by setting some configurations with the AWS CLI. If you have v1 of the AWS CLI, make sure to uninstall it first. Then you can follow Amazon's instructions for installing AWS CLI v2 on [Mac](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-mac.html), [Windows](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-windows.html), or [Linux](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html).

### Docker (optional)

The `docker` command is currently only required if you want to build and upload Docker images with the Provose [`images` module](../reference/images/). The Docker documentation describes [how to install the `docker` command](https://docs.docker.com/get-docker/).

## Set up your credentials

Provose strongly discourages placing credentials in code.

If you want to run Provose (and its underlying Terraform setup) on your local machine, we recommend placing your credentials in the `.aws/credentials` file in your home directory, with additional configuration in the `.aws/config` directory. The AWS documentation has more information on [setting up configuration and credential files](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).

If you have multiple sets of credentials in these files, you can tell Provose which credentials you want to use with the `AWS_PROFILE` environment variable.

You can also set credentials directly with the environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

If you are running Provose on an AWS EC2 instance, Provose can use the credentials in the IAM instance profile for the instance. AWS has a documentation page about [how to use instance profiles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html).

## Set up an S3 bucket to store Terraform state

Terraform operates by tracking the state of your AWS configuration and then applying any differences between your local Terraform files and the state. By default, Terraform stores state information in a local file named `terraform.tfstate`, but Terraform [can also work with state stored remotely in the cloud](https://www.terraform.io/docs/state/remote.html).

Provose recommends that you store your Terraform state in an Amazon S3 bucket that is accessible to every user that needs to run Terraform, but nobody else. Your Terraform state contains secrets that could be used to compromise resources in your AWS account, so make sure that nobody untrusted can access it.

Terraform's [enterprise version](https://www.hashicorp.com/products/terraform/) also offers remote state storage, but that is beyond the scope of this tutorial. All features of Provose are available through the free and open-source version of Terraform.

If the domain name you have chosen was `example-internal.com` and you want to deploy to the AWS region `us-east-1`, then Provose's recommended Terraform state configuration looks like:

```terraform
terraform {
  # Look out. We're going to replace this `backend "local"` block with
  # a `backend "s3"` block later in the tutorial.
  backend "local" {
    path = "terraform.tfstate"
  }
  required_providers {
    # Provose v1.0 currently uses the Terraform AWS provider 2.54.0.
    # Stick with this version for your own code to avoid compatibility
    # issues.
    aws = "2.54.0"
  }
}

provider "aws" {
  region = "us-east-1"
}

# This is an AWS Key Management Service (KMS) key that we will use to
# encrypt the AWS S3 bucket.
resource "aws_kms_key" "terraform" {
  description = "Used to encrypt the Terraform state S3 bucket at rest."
  tags = {
    Provose = "terraform"
  }
  lifecycle {
    prevent_destroy = true
  }
}

# This is where we store the Terraform remote tfstate.
resource "aws_s3_bucket" "terraform" {
  # This should be a globally-unique Amazon S3 bucket, although it
  # should not be accessible outside of the AWS credentials you use to run
  # Terraform.
  bucket = "terraform-state.example-internal.com"
  acl    = "private"
  region = "us-east-1"

  # For security and compliance reasons, Provose recommends that you
  # configure AWS Key Management Service (KMS) encryption at rest for
  # the bucket.
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.terraform.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  versioning {
    enabled = true
  }
  tags = {
    Provose = "terraform"
  }
  # This lifecycle parameter prevents Terraform from destroying the
  # bucket that contains its own state.
  lifecycle {
    prevent_destroy = true
  }
}

# This prevents public access to our remote Terraform tfstate.
resource "aws_s3_bucket_public_access_block" "terraform" {
  bucket = aws_s3_bucket.terraform.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  lifecycle {
    prevent_destroy = true
  }
}
```

We recommend that you place the above configuration in a file named `terraform.tf`. To keep things organized, you may want to put your Provose configuration into a separate file.

This configuration creates the S3 bucket that you will use for remote state, but Terraform must store state in the local file `terraform.tfstate` before the S3 bucket is created.

After saving `terraform.tf`, run the following commands:

```
terraform init
terraform plan -out plan.out
terrafrom apply "plan.out"
```

## Begin using Terraform remote state

Now that we have created the S3 bucket we need to store remote state, we need to change the `terraform` block at the beginning of our `terraform.tf` file to reference remote state:

```terraform
terraform {
  backend "s3" {
    # This is the name of the S3 bucket we use to store Terraform state.
    # We create this bucket below.
    bucket = "terraform-state.example-internal.com"
    key    = "tfstate"
    region = "us-east-1"
    acl    = "private"
  }
  required_providers {
    # Provose v1.0 currently uses the Terraform AWS provider 2.54.0.
    # Stick with this version for your own code to avoid compatibility
    # issues.
    aws = "2.54.0"
  }
}
```

Rerun `terraform init` and you should see the following prompt asking if you want to copy your local state to the S3 bucket. Answer with `yes`.

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "s3" backend. No existing state was found in the newly
  configured "s3" backend. Do you want to copy this state to the new "s3"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes
```

## Initialize Provose

Now that you have Terraform's remote state configuration set up, create another file named after the project you want to create with Provose. In these examples, we will go with the name `myproject`.

In `myproject.tf`, we will enter the bare minimum Provose configuration:

```terraform
module "myproject" {
  source = "github.com/provose/provose?ref=v1.0.2"
  provose_config = {
    authentication = {
      aws = {
        region = "us-east-1"
      }
    }
    name                 = "myproject"
    internal_root_domain = "example-internal.com"
    internal_subdomain   = "myproject"
  }
}
```

Run `terraform init` again to download Provose v1.0.2 and the Terraform modules and providers that Provose depends on.

You should rerun `terraform init` every time you update Provose, or if you change any Terraform modules or providers that you use elsewhere in your code.

## Start using Provose modules

You can now use Provose modules--like [`containers`](../reference/containers/), [`s3_buckets`](../reference/s3_buckets/), [`mysql_clusters`](../mysql_clusters/), and more--to configure the AWS infrastructure that you need.

Below is an example of two modules implemented in `myproject.tf`

```terraform
{% include_relative examples/full_example/myproject.tf %}
```

You can read more about Provose's capabilities in the [Reference](../reference/).
