---
title: containers
parent: Reference v1.1
grand_parent: Docs - v1.1
---

# containers

## Description

The Provose `containers` module automatically configures Docker containers to run on AWS Elastic Container Service (ECS).

Provose abstracts over ECS concepts like clusters, services, task definitions, and image repositories. The `containers` module also helps set up Route 53 DNS settings, Amazon Certificate Manager (ACM) certificates to route TLS traffic, and AWS Application Load Balancer (ALBs) to balance the traffic across multiple containers.

Provose supports running containers on EC2 instances or via AWS Fargate. It is generally easier to use AWS Fargate, but you should choose EC2 if you want to be able to SSH into the host instances or bind-mount host paths into your containers.

Provose can pull publicly-available Docker images from Docker hub, or you can use the Provose images module to build and upload your own containers to Provose-managed Elastic Container Registry image repositories.

## Examples

### Running a public Docker container on AWS ECS EC2.

This example shows a total of four nginx "Hello World" containers running on two EC2 instances of the `t3.small` instance type.

```terraform
{% include_relative examples/containers/hello_ec2.tf %}
```

### Running a public Docker image on AWS Fargate.

This example shows ten nginx "Hello World" containers running on AWS Fargate.

```terraform
{% include_relative examples/containers/hello_fargate.tf %}
```

## Inputs

- `image` -- **Required.** This object defines information about the Docker image that we are deploying.

  - `name` -- **Required.** The name of the image to use, including the namespace. For example, to use the [nginxdemos/hello](https://hub.docker.com/r/nginxdemos/hello/) container on Docker Hub, set `name` to `"nginxdemos/hello"` and `private_registry` to `false`.

  - `tag` -- **Required.** The Docker Registry tag of the image to use. This may be a particular tag or version number in Docker Hub or Elastic Container Registry (ECR). However, `"latest"` is a common value to pick the latest version of an image in the registry.

  - `private_registry` -- **Required.** Set this to `true` to look for a container with the name set in `name` in your AWS account's private Elastic Container Registry (ECR). You should configure the ECR repository for this image with the [Provose `image` key](../images/). Set this to `false` to use a publicly-available container on Docker Hub.

- `instances` -- **Required.** This is an object that defines how this container is run.

  - `instance_type` -- **Required.** Set this to `"FARGATE"` to deploy the containers on AWS Fargate. Set this to `"FARGATE_SPOT"` to use Fargate with Spot instances--which can [give cost savings of up to 70%](https://aws.amazon.com/blogs/compute/deep-dive-into-fargate-spot-to-run-your-ecs-tasks-for-up-to-70-less/). Note that with Fargate, it will not be possible to use `bind_mounts` to mount to the host. However, if you want to deploy these containers on AWS EC2 instances, set this to the instance type of your choice, like `"t3.small"`. Keep in mind that AWS does not make all instance types available in all Availability Zones.

  - `container_count` -- **Required.** This is the number of containers to deploy.

  - `instance_count` -- **Optional.** This field is required if `instance_type` is an EC2 instance type, but is unused when `instance_type` is `"FARGATE"` or `"FARGATE_SPOT"`.

  - `key_name` -- **Optional.** Set this to the name of an AWS EC2 key pair in your account to enable SSH access to the instances. This only works if the `instance_type` is an EC2 instance type and _not_ `"FARGATE"` or `"FARGATE_SPOT"`.

  - `bash_user_data` -- **Optional.** This is a bash script that will be run on the creation of the underlying AWS instances. This field does nothing if the container is deployed with AWS Fargate.

  - `cpu` -- **Required.** The CPU units given to each container. 1024 CPU units maps to one vCPU on AWS. This is a [minimum](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html) of 128 if `instance_type` is an EC2 instance type, or 256 if the instance type is Fargate.

  - `memory` -- **Required.** The amount of memory--in megabytes--given to each container. This must be in [proportion](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html). For example, a Fargate task with 256 CPU units can have 512, 1024, or 2048 megabytes of memory.

- `entrypoint` -- **Optional.** Defines a custom container entrypoint, if you do not want to use the entrypoint defined within the container.

- `command` -- **Optional.** Defines a custom container command. Use this if you do not want to use the command defined within the container.

- `environment` -- **Optional.** This is a mapping of environment variables and their values.

- `secrets` -- **Optional.** This is a mapping of environment variable names to Provose secret names.

- `efs_volumes` -- **Optional.** This is a mapping of the AWS Elastic File System (EFS) volumes to mount within the container.

  - `container_mount` -- **Required.** The path in the container to mount the EFS volume.

- `bind_mounts` -- **Optional.** This is only for containers running with an EC2 `instance_type`. These are mounted filesystem paths from the EC2 host into the containers. This will not work for containers running on AWS Fargate because there is no concept of a host with a filesystem.

  - `host_mount` -- **Required.** The directory on the container host to mount in the container.

  - `container_mount` -- **Required.** The path in the container to mount the host filesystem.

- `public` -- **Optional.** This mapping configures network access from the public IPv4 Internet to the container.

  - `https` -- **Optional.** This mapping configures the Application Load Balancer (ALB) that allows HTTP/HTTPS requests from the public Internet to the container. Use this if your container is an HTTP server.

    - `public_dns_names` -- **Required.** A list of DNS names--like `example.com` or `subdomain.example.com` to point at this container. Your AWS account must own the underlying domain name and be able to set the DNS records. Provose will also generate Amazon Certificate Manager (ACM) certificate for the DNS names provided--enabling access to the container via HTTPS.

    - `internal_http_port` -- **Required.** This is the port exposed by the container to serve HTTP requests. The load balancer listens on port 80 and 443 to forward ports to the given port on the container.

    - `internal_http_health_check_path` -- **Required.** This is a URL path, like `/robots.txt`, that the Application Load Balancer (ALB) checks to determine whether the container is healthy. This path must return a 200 OK If the ALB decides a container is unhealthy, it will be removed from routing.

    - `internal_http_health_check_success_status_codes` -- **Optional.** A list or range of HTTP status codes that the Application Load Balancer (ALB) will consider to be healthy. This can be a list of values like `"200,301"` or a range of values like `"200-299"`. This corresponds with the [`matcher` parameter](https://www.terraform.io/docs/providers/aws/r/lb_target_group.html#matcher) of `health_check` objects on Terraform `aws_lb_target_group` resources. This defaults to only considering the HTTP code 200 as healthy.

    - `internal_http_health_check_timeout` -- **Optional.** This sets the timeout for the HTTP requests that the Application Load Balancer (ALB)'s health checks. If this field is omitted, it defaults to 5 seconds.

    - `stickiness_cookie_duration_seconds` -- **Optional.** If this value is present, it enables _stickiness_ on the Application Load Balancer. Stickiness is the mechanism for client requests to consistently be routed to the same container instance behind the Application Load Balancer (ALB). The ALB sets an HTTP cookie for the first client request it receives, and then checks for the cookie on subsequent requests. The cookie eventually expires, and this value sets the expiration for the cookie--in seconds.

- `vpc` -- **Optional.** This mapping configures network access to the container from within the VPC that Provose creates.

  - `https` -- **Optional.** This mapping configures the Application Load Balancer (ALB) that allows HTTP/HTTPS traffic from within the VPC. Use this if your container is an HTTP server.

    - `vpc_dns_names` -- **Required.** A list of DNS names--like `example.com` or `subdomain.example.com` to point at this container. **These domains must be used to serve internal traffic to your VPC. The `vpc` Provose configuration does not serve traffic to the public Internet.** Your AWS account must own the underlying domain name and be able to set the DNS records. Provose will also generate Amazon Certificate Manager (ACM) certificate for the DNS names provided--enabling access to the container via HTTPS.

    - `internal_http_port` -- **Required.** This is the port exposed by the container to serve HTTP requests. The load balancer listens on port 80 and 443 to forward ports to the given port on the container.

    - `internal_http_health_check_path` -- **Required.** This is a URL path, like `/robots.txt`, that the Application Load Balancer (ALB) checks to determine whether the container is healthy. This path must return a 200 OK If the ALB decides a container is unhealthy, it will be removed from routing.

    - `internal_http_health_check_timeout` -- **Optional.** This sets the timeout for the HTTP requests that the Application Load Balancer (ALB)'s health checks. If this field is omitted, it defaults to 5 seconds.

    - `stickiness_cookie_duration_seconds` -- **Optional.** If this value is present, it enables _stickiness_ on the Application Load Balancer. Stickiness is the mechanism for client requests to consistently be routed to the same container instance behind the Application Load Balancer (ALB). The ALB sets an HTTP cookie for the first client request it receives, and then checks for the cookie on subsequent requests. The cookie eventually expires, and this value sets the expiration for the cookie--in seconds.

- `s3_buckets` -- **Optional.** This is a mapping of S3 buckets to the classes of permissions available to the instances. The four classes of permissions available are `list`, `get`, `put`, and `delete`, and the values for each one is `true` or `false`. To use this configuration, place the `s3_buckets` key **inside** a block that defines a container. Below is an example of how to give the container access to two buckets--one with `list` and `get` permissions, and another with `get` and `delete` permissions.

```terraform
s3_buckets = {
  "some-bucket-name.example-internal.com" = {
    permissions = {
      list   = true
      get    = true
      put    = false
      delete = false
    }
  }
  "another-bucket.com" = {
    permissions = {
      list   = false
      get    = true
      put    = false
      delete = true
    }
  }
}
```

## Outputs

Provose provides these Terraform outputs to enable users to patch certain advanced configurations that cannot be configured via the inputs.

- `containers.aws_security_group.container__internal_http_port` -- A mapping between container names and the [`aws_security_group` resources](https://www.terraform.io/docs/providers/aws/r/security_group.html) that govern network access to each container.

- `containers.aws_ecs_cluster.container` -- This is a mapping between container names and their corresponding [`aws_ecs_cluster` resources](https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html). Provose gives every container definition its own cluster.

- `containers.aws_ecs_task_definition.container` -- A mapping between container names and their corresponding [`aws_ecs_task_definition` resource]()https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html.

- `containers.aws_lb_target_group.container__public_https` -- A mapping between container names and the containers' corresponding [`aws_lb_target_group` resources](https://www.terraform.io/docs/providers/aws/r/lb_target_group.html).

- `containers.aws_lb_target_group.container__vpc_https` -- These are [`aws_lb_target_group` resources](https://www.terraform.io/docs/providers/aws/r/lb_target_group.html) for each container that give HTTPS access from within a VPC.

- `containers.aws_lb_listener_rule.container__public_https` -- These are [`aws_lb_listener_rule` resources](https://www.terraform.io/docs/providers/aws/r/lb_listener_rule.html) for each container that give public HTTPS access.

- `containers.aws_ecs_service.container` -- A mapping of [`aws_ecs_service` resources](https://www.terraform.io/docs/providers/aws/r/ecs_service.html) for each container name. In Provose, each container only belongs to one service.

- `containers.aws_instance.container__instance` -- A mapping of [`aws_instance` resources](https://www.terraform.io/docs/providers/aws/r/instance.html) being used to host containers. This will be empty if you are running all of your containers with AWS Fargate as opposed to using EC2 hosts.

- `containers.aws_route53_record.container__instance` -- A mapping of [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) for EC2 instances hosting containers. This will be empty if you are running all of your containers with AWS Fargate as opposed to EC2.

- `containers.aws_route53_record.container__public_https` -- A mapping of [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that point to public HTTPS websites served by containers.

- `containers.aws_route53_record.container__public_https_validation` -- A mapping of [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that were created specifically to validate the Amazon Certificate Manager certificates for domain names that we point a container to.
- `containers.aws_route53_record.container__vpc_https` -- A mapping of [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) created for DNS resolution to HTTPS websites _within the VPC._

- `containers.aws_route53_record.container__instance_spot` -- A mapping of [`aws_route53_record` resources](https://www.terraform.io/docs/providers/aws/r/route53_record.html) for container spot instances.

- `containers.aws_route53_zone.external_dns__for_containers` -- A mapping from container names to [`aws_route53_zone` resources](https://www.terraform.io/docs/providers/aws/r/route53_zone.html) describing the Route 53 zones that contain the domain names that serve traffic to each container.

- `containers.aws_acm_certificate.container__public_https` -- A mapping of [`aws_acm_certificate` resources](https://www.terraform.io/docs/providers/aws/r/acm_certificate.html) representing the TLS certificates that communicate connections to the container from the public Internet.

- `containers.aws_acm_certificate_validation.container__public_https_validation` -- A mapping of [`aws_acm_certificate_validation` resources](https://www.terraform.io/docs/providers/aws/r/acm_certificate_validation.html). Use this to debug issues with Amazon Certificate Manager (ACM) certificate validation.

## Implementation details

### Container networking modes

Containers launched with the `"FARGATE"` instance type are launched with the [`"awsvpc"`](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking.html) container networking mode.

Containers launched with one of the EC2 instance types are launched with the [`"bridge"`](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html) container networking mode. This is because ECS EC2 containers do not have public Internet access unless the containers are both launched in a private subnet and connected to the Internet through a NAT gateway. The NAT gateway costs additional money, so we can save money by using the `"bridge"` networking mode instead. This, according to Amazon, is slightly less performant, but the faster `"awsvpc"` networking mode is still available for Fargate containers through Provose.
