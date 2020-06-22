resource "random_password" "pg1_password" {
  # AWS RDS passwords must be between 8 and 41 characters
  length = 41
  # This is a list of special characters that can be included in the
  # password. This lits omits characters that often need to be
  # escaped.
  override_special = "()-_=+[]{}<>?"
}

resource "random_password" "bigpg_password" {
  length           = 41
  override_special = "()-_=+[]{}<>?"
}

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
  postgresql_clusters = {
    # This creates an AWS Aurora PostgreSQL cluster available
    # at the host pg1.production.example-internal.com.
    # This host is only available within the VPC.
    pg1 = {
      engine_version = "11.6"
      database_name  = "exampledb"
      password       = random_password.pg1_password.result
      instances = {
        instance_type  = "db.r5.large"
        instance_count = 1
      }
    }
    # This creates a cluster at bigpg.production.example-internal.com.
    # This host is only available within the VPC.
    bigpg = {
      engine_version = "11.6"
      database_name  = "exampledb"
      password       = random_password.bigpg_password.result
      instances = {
        instance_type  = "db.t3.medium"
        instance_count = 3
      }
    }
  }
}
