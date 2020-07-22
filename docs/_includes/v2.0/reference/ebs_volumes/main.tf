module "myproject" {
  source = "github.com/provose/provose?ref=v2.0.0-beta1"
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
  ebs_volumes = {
    some_volume = {
      availability_zone = "us-east-1c"
      size_gb           = 100
    }
    provisioned_volume = {
      availability_zone = "us-east-1a"
      size_gb           = 50
      iops              = 2500
      type              = "io1"
      encrypted         = true
    }
  }
}
