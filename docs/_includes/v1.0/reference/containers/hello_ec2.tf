
module "myproject-ec2" {
  source = "github.com/provose/provose?ref=v1.0.1"
  provose_config = {
    authentication = {
      aws = {
        region = "us-east-1"
      }
    }
    name                 = "myproject-ec2"
    internal_root_domain = "example-internal.com"
    internal_subdomain   = "myproject-ec2"
  }
  containers = {
    hellooec2 = {
      image = {
        name             = "nginxdemos/hello"
        tag              = "latest"
        private_registry = false
      }
      public = {
        https = {
          internal_http_port              = 80
          internal_http_health_check_path = "/"
          public_dns_names                = ["ec2.example.com"]
        }
      }
      instances = {
        instance_type   = "t2.small"
        container_count = 4
        instance_count  = 2
        cpu             = 256
        memory          = 512
        bash_user_data  = <<EOF
#!/bin/bash
# Install Vim on the container hosts.
yum update -y
yum install vim
EOF
      }
    }
  }
}
