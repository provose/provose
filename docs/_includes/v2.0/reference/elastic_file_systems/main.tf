module "myproject" {
  source = "github.com/provose/provose?ref=v2.0.0-beta5"
  provose_config = {
    authentication = {
      aws = {
        region = "us-east-1"
      }
    }
    name                 = "myproject"
    internal_root_domain = "example-internal.com"
    internal_subdomain   = "myproject"
  }
  elastic_file_systems = {
    # This creates an Elastic File system at the domain name
    # myfiles.myproject.example-internal.com, which is only accessible
    # by the VPC created by the "myproject" Provose module.
    "myfiles" = {}
  }
}
