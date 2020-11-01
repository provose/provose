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
  ec2_spot_instances = {
    my-instance-name = {
      spot_price = 0.1
      instances = {
        instance_type = "t3.micro"
        # Create and name keys pairs in the AWS console. You can attach
        # one key pair to an instance on creation, but then you can add
        # more SSH keys via the user's ~/.ssh/authorized_keys file.
        key_name = "james_laptop"
      }
      public = {
        # Open port 22 for public SSH access.
        tcp = [22]
      }
      vpc = {
        # Open ports 80 and 443 to run HTTP and HTTPS servers only
        # available in the VPC.
        tcp = [80, 443]
      }
    }
  }
}
