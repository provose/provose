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
  https_redirects = {
    "some.example.com" = {
      status_code     = 302
      destination     = "https://destination.com"
      forwarding_type = "DOMAIN_NAME"
    }
    "example.com" : {
      destination     = "https://google.com/robots.txt"
      forwarding_type = "EXACT_URL"
    }
  }
}
