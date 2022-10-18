
module "myproject-ec2" {
  source = "github.com/provose/provose?ref=v3.0.0"
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
        /* Make sure to use an AWS AMI that is ECS-optimized.
         * You can search for ECS-optimized AMIs in the
         * AWS AMI catalog:
         * https://us-west-1.console.aws.amazon.com/ec2/v2/ */
        ami_id          = "ami-0f71b77f57e47333c"
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
