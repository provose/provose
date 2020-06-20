module "myproject" {
  source = "github.com/provose/provose?ref=v1.0.0"
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
  ec2_instances = {
    my-instance = {
      public_tcp        = [22]
      purchasing_option = "ON_DEMAND"
      instances = {
        instance_type = "t3.micro"
      }
    }
  }
}
