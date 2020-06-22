module "myproject" {
  source = "github.com/provose/provose?ref=v1.0.1"
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
    # This creates 1 AWS EC2 instance named `my-instance-name`
    my-instance-name = {
      public_tcp        = [22]
      public_udp        = [53]
      internal_tcp      = [443]
      purchasing_option = "ON_DEMAND"

      instances = {
        instance_type  = "t3.micro"
        instance_count = 1
        key_name       = "james_laptop"
      }
      root_volume = {
        size_gb = 100
      }
      bash_user_data = <<EOF
#!/bin/bash
# This script updates the yum package manager and install the NGINX web server.
yum update -y
yum install -y nginx
EOF
    }
  }
}

output "output" {
  value = try(module.myproject.ec2_instances.aws_instance.on_demand["my-instance-name-0"], null)
}
