resource "random_password" "my1_password" {
  # AWS RDS passwords must be between 8 and 41 characters
  length = 41
  # This is a list of special characters that can be included in the
  # password. This lits omits characters that often need to be
  # escaped.
  override_special = "()-_=+[]{}<>?"
}

resource "random_password" "bigmy_password" {
  length           = 41
  override_special = "()-_=+[]{}<>?"
}

module "myproject" {
  source = "github.com/provose/provose?ref=v1.1.0"
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
  mysql_clusters = {
    # This creates an AWS Aurora MySQL cluster available
    # at the host my1.production.example-internal.com.
    # This host is only available within the VPC.
    my1 = {
      engine_version = "5.7.mysql_aurora.2.08.0"
      database_name  = "exampledb"
      password       = random_password.my1_password.result
      instances = {
        instance_type  = "db.r5.large"
        instance_count = 1
      }
    }
    # This creates a cluster at bigmy.production.example-internal.com.
    # This host is only available within the VPC.
    bigmy = {
      engine_version = "5.7.mysql_aurora.2.08.0"
      database_name  = "exampledb"
      password       = random_password.bigmy_password.result
      instances = {
        instance_type  = "db.t3.small"
        instance_count = 3
      }
    }
  }
}
