
module "myproject-fargate" {
  source = "github.com/provose/provose?ref=v3.0.0"
  provose_config = {
    authentication = {
      aws = {
        region = "us-east-1"
      }
    }
    name                 = "myproject-fargate"
    internal_root_domain = "example-internal.com"
    internal_subdomain   = "myproject-fargate"
  }
  containers = {
    hellofargate = {
      image = {
        name             = "nginxdemos/hello"
        tag              = "latest"
        private_registry = false
      }
      public = {
        https = {
          internal_http_port              = 80
          internal_http_health_check_path = "/"
          public_dns_names                = ["fargate.example.com"]
        }
      }
      instances = {
        # set `instance_type` to be "FARGATE_SPOT" to save money by
        # using Spot instances behidn the scenes.
        instance_type   = "FARGATE"
        container_count = 10
        cpu             = 256
        memory          = 512
      }
    }
  }
}
