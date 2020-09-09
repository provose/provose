variable "some_secret" {
  type    = string
  default = "This is how to use a Terraform variable."
}

module "myproject" {
  source = "github.com/provose/provose?ref=v2.0.0-beta4"
  provose_config = {
    authentication = {
      aws = {
        region = "us-east-1"
      }
    }
    name                 = "myproject"
    internal_root_domain = "example-internal.com"
    internal_subdomain   = "production"
  }
  # Be careful not to put the actual values of your secrets into Git
  # or your version control.
  secrets = {
    root_password = "...insert password here..."
    secret_key    = "...insert secret key here..."
    # Use Terraform variables to specify secret values so they don't end
    # up in your source code.
    other_secret = var.some_secret
  }
  # Here we include a container configuration as an example of how
  # other Provose modules use secrets.
  containers = {
    helloexample = {
      # these secrets named `root_password` and `secret_key` are retrieved
      # from AWS Secrets Manager and inserted into this Elastic Container Service
      # configuration as environment variables named `ROOT_PASSWORD` and
      # `APPLICATION_SECRET_KEY`.
      secrets = {
        ROOT_PASSWORD          = "root_password"
        APPLICATION_SECRET_KEY = "secret_key"
      }
      # The configuration below this comment is just standard setup
      # for a container.
      image = {
        name             = "nginxdemos/hello"
        tag              = "latest"
        private_registry = false
      }
      public = {
        https = {
          internal_http_port              = 80
          internal_http_health_check_path = "/"
          public_dns_names                = ["demo.example.com"]
        }
      }
      instances = {
        instance_type   = "FARGATE"
        container_count = 10
        cpu             = 256
        memory          = 512
      }
    }
  }
}
