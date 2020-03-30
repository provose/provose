# TODO

- Create a tool to generate an OVPN config for ever user, embedding their private key for easy access.
- Add the ability to automatically add ingress authorization for the VPN https://github.com/terraform-providers/terraform-provider-aws/issues/7494
- Enable encryption at rest and in transit for the following data stores:
  - MySQL
  - PostgreSQL
  - Elasticsearch
  - S3 buckets
  - Redis

# Naming guidelines

Names for services and secrets should generally be:

- between 3 and 28 characters
- a-z lowercase letters
- 0-9
- hyphens

Underscores are generally not accepted. However, for environment variable names,
hyphens must be substituted with underscores.

# Limitations

## Dependency on the AWS CLI

Powercloud has a dependency on the AWS CLI (written in Python). This means the CLI needs to
be installed in the PATH and the CLI needs to be able to find the right credentials
and its region.

## Secrets stored in the Terraform state

Powercloud's VPN server and CA private keys are generated within Terraform and thus stored
in Terraform state. It is important to use a secure type of Terraform state when using
Powercloud, such as an encrypted S3 bucket with strict access controls.

## Internal domain names and TLS certificates

Currently containers that want to serve VPC HTTPS can only serve traffic on subdomains of
`${var.internal_subdomain}.${var.root_domain}` as opposed to arbitrary subdomains of arbitrary
domains that the user might want to register.

# Module reference

## `container`

Example:

```
module "powercloud" {
  container = {
    # This `helloworld` key signifies one ECS deployment.
    helloworld = {
      environment = {
        ENV_VAR_1 = "some_value"
        ANOTHER_VAR = "different value"
      }
      image = {
        name = "nginxdemos/hello"
        tag = "latest"
        private_registry = false
      }
      public = {
        https = {
          internal_http_port = 80
          internal_http_health_check_port = 80
          internal_http_health_check_path = "/"
          public_dns_names = ["hello-i-am-bob.example.com", "another-domain-name.com"]
        }
      }
      instances = {
        instance_type = "t3.small"
        container_count = 3
        instance_count = 2
        cpu = 256
        memory = 512
      }
      secrets = {
        SECRET_ENV_VAR_NAME = "name_of_secret"
      }
    }
  }
}
```

## `elasticsearch`

## `jumphost`

## `mysql`

## `postgresql`

## `redis`

## `redisinsight`

## `secrets`

## `statsd_graphite_grafana`

## `vpn
