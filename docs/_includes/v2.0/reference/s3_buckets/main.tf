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
  s3_buckets = {
    "example-bucket-name.example.com" = {}
    "some-other-unique-bucket-name" = {
      versioning = true
    }
    "third-bucket" = {
      acl = "private"
    }
  }
}
