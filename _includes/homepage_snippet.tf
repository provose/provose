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
