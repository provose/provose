---
title: batch
parent: Reference v2.0
grand_parent: Docs - v2.0 (LATEST)
---

# batch

## Description

The Provose `batch` configures resources for AWS Batch, which is fully-managed batch processing system for Dockerized workloads.

### How AWS Batch works

A full explanation of AWS Batch is outside the scope of the Provose documentation. You can learn more by reading the [AWS Batch documentation](https://docs.aws.amazon.com/batch/index.html).

However, there are some important AWS Batch concepts to understand in order to use them with Provose:

- **Jobs** -- A Job describes a computation to be done as described with a Docker image and some parameters (see below). _This Provose module does not specify or submit Jobs._ You must submit them with the AWS Console, the AWS API or the AWS CLI. The AWS Batch documentation page titled [Submitting a Job](https://docs.aws.amazon.com/batch/latest/userguide/submit_job.html) has more information.

- **Job Definitions** -- A Job Definition is a blueprint for how Jobs are made. Job Definitions are configured below under the `job_definitions` key. Some of the parameters specified in a Job Definition can be overriden when specifying a job.

- **Docker images** -- AWS Batch Job Definitions are based on a Docker image that contains the code to be run in a job. You can read more about building and running Docker images on your local machine in [the Docker documentation](https://docs.docker.com/get-started/part2/). You can create images on your your local computer and [use Provose to upload your images](../images/) to Amazon Web Services, after which they will be available for AWS Batch.

- **Job Queues** -- A Job Queue accepts Jobs until the Compute Environment is ready to accept the Job. You can define multiple Job Queues with different priorities below with the `job_queues` key.

- **Compute Environments** -- A Compute Environment pulls Jobs from the Job Queues to run them. A Compute Environment contains a pool of EC2 instances--with instance types of your choosing. The number of instances in the Compute Environment can scale up or down with the length of the queue.

You can read more precise versions of the above definitions in the [AWS Batch documentation](https://docs.aws.amazon.com/batch/latest/userguide/what-is-batch.html).

AWS Batch allows many-to-many configurations between Job Definitions and Compute Environments, but for the sake of simplicity, Provose assumes that you'll only want one Compute Environment for every Job Definition you write.

If you need more complex configurations, you should write your AWS Batch configuration directly with the [Terraform AWS Batch module](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/batch_compute_environment).

### Security limitations of AWS Batch

AWS Elastic Container Service (ECS) can fetch secrets from AWS Secrets Manager and present them as environment variables to a container. However, AWS Batch currently does not have a similar integration with Secrets Manager. If you want to pass secrets to AWS Batch using environment variables, they will not be encrypted.

If you want to pass environment variables to a container using AWS Batch, you can use the `environment` key documented below. You can use this method to pass secret values, but it would be more secure for your container process to contact AWS Secrets Manager directly.

### Naming conventions

The names you provide Provose for queue and job names are global within the AWS Region. This means that if you use AWS Batch in two different Provose modules, you should take care not to reuse the same names.

## Examples

```terraform
{% include_relative examples/batch/first.tf %}
```

## Inputs

- `instances` -- **Required.** This is an object that defines the compute resources for the given AWS Batch Compute Environment.

  - `instance_types` -- **Required.** This is a list of AWS EC2 instance types that will run the Jobs. Not all instance types are available for AWS Batch. The list must also only contain instances of the same CPU architecture--you cannot have both x86 instances and ARM instances in the same list.

  - `compute_environment_type` -- **Required.** The type of compute environment. Set this to `"EC2"` to deploy EC2 On-Demand instances for this Compute Environment. If you set this vlaue to `"SPOT"`, you can save money by using AWS Spot Instances instead.

  - `min_vcpus` -- **Required.** This is the minimum number of virtual CPUs (vCPUs) to maintain in the Compute Environment. These many vCPUs will be continually available for new jobs, even if the queue is empty. However, you can set this value to `0` to instruct AWS Batch to shut off the compute resources when the queue is empty.

  - `max_vcpus` -- **Required.** This is the maximum number of virtual CPUs (vCPUs) that are available in the Compute Environment.o

  - `ami_id` -- **Optional.** If you wish, you can set this to a custom Amazon Machine Image for the compute resources to run. Presumably most of your job's software is written in the Docker container, but you may need a custom AMI to mount filesystems or install device drivers.

- `job_queues` -- **Required.** This is **mapping** _from_ queue names to objects with the given keys.

  - `state` -- **Required.** This is `"ENABLED"` to enable the queue or `"DISABLED"` to disable the queue.

  - `priority` -- **Required.** This is an integer value that describes the priority of this queue. A larger number gives this queue a higher priority in the attached Compute Environment.

- `job_definitions` -- **Optional.** This is a **mapping** from job definition names to job definition values.

  - `image` -- **Required.** This defines the Docker image deployed by this AWS Batch job.

    - `name` -- **Required.** The name of the Docker image to deploy.

    - `tag` -- **Required.** This is the tag of the image to deploy. This is often a specific version or the string `"latest"`.

    - `private_registry` -- **Required.** Set this to `true` if the given image is ion your AWS account's private Elastic Container Registry. If set to `false`, AWS Batch will look for an image with the given name in the public Docker Hub registry.

  - `vcpus` -- **Required.** The number of vCPUs to dedicate to each Job that belongs to this Job Definition.

  - `memory` -- **Required.** The amount of memory--in megabytes--designated to each job.

  - `command` -- **Required.** This is the command to pass to the Docker container. Note that AWS Batch does not currently let you override the container entrypoint.

  - `environment` -- **Optional.** This is **mapping** from environment variable names to their values. Remember, these values are uenncrypted. AWS Batch currently does not have a way to directly pull encrypted secrets from AWS Secrets Manager.

## Outputs

<!--
 - `batch.aws_iam_role.batch__execution_role` --
 - `batch.aws_iam_role.batch__service_role` --
 - `batch.aws_iam_role.batch__spot_fleet_role` --
 - `batch.aws_iam_instance_profile.batch__execution_role` --
 -->

- `batch.aws_security_group.batch` -- A mapping from AWS Batch Compute Environment names to [`aws_security_group` resources](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/security_group). By default, the security groups allow AWS Batch Jobs outbound access to the Internet. This may be undesirable for you if you are running jobs containing untrusted code or have other needs for network isolation.

- `batch.aws_batch_compute_environment.batch` -- A mapping from AWS Batch Compute Environment names to [`aws_batch_compute_environment` resources](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/batch_compute_environment).

- `batch.aws_batch_job_queue.batch` -- A mapping from AWS Batch Job Queue names to [`aws_batch_job_queue` resources](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/batch_job_queue).

- `batch.aws_batch_job_definition.batch` -- A mapping from AWS Batch Job Definition names to [`aws_batch_job_definition` resources](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/batch_job_definition).
