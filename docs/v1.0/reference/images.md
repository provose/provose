---
title: images
parent: Reference v1.0
grand_parent: Docs - v1.0
search_exclude: true
---

# images

## Description

The Provose `images` module creates AWS Elastic Container Registry (ECR) image repositories, optionally building containers from local directories to upload.

### How to build and upload Docker images

If you have the `docker` command installed on the machine you use to run Provose, then Provose can build and upload your container when it creates the repository to upload your container. The Docker documentation describes [how to install the `docker` command](https://docs.docker.com/get-docker/).

To upload new versions of your container manually, visit the [Elastic Container Registry page in the AWS console](https://console.aws.amazon.com/ecr/repositories). Select the repository that you created via Provose and click the button **View push commands**. This will give you commands specific to your AWS account to upload containers from a Windows, Mac, or Linux machine.

## Examples

```terraform
{% include v1.0/reference/images/image.tf %}
```

## Inputs

- `local_path` -- **Optional.** This is the filesystem path to pass to `docker build`. This builds, tags, and uploads a container to the registry. The path you pass should have a `Dockerfile`.

## Outputs

- `image.aws_ecr_repository.image` -- map with a key for every repository name and every value is a Terraform [`aws_ecr_repository`](https://www.terraform.io/docs/providers/aws/r/ecr_repository.html) type.

- `image.aws_ecr_repository_policy.image` -- A map with a key for every repository name and every value is a Terraform [`aws_ecr_repository_policy`](https://www.terraform.io/docs/providers/aws/r/ecr_repository_policy.html) type.
