module "myproject" {
  source = "github.com/provose/provose?ref=v3.0.0-beta1"
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
  images = {
    "my_organization/my_container_1" = {
      # local_path is the location of the Dockerfile or the build context
      local_path = "../../src/my_container_1"
    }
    "my_organization/my_container_2" = {
      local_path = "../../src/my_container_2"
    }
    # It is also possible to not specify a local path, and instead create
    # an Amazon Web Services Elastic Container Registry (ECR) repository
    # to where you will push an image to later.
    # Note that if you have containers that depend on this ECR images, the
    # Application Load Balancer will throw HTTP 503 errors until you have
    # uploaded an image that can run.
    "my_organization/my_container_2" = {}
  }
}
