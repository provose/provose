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
  overrides = {
    # `mysql-subnets` and `postgresql-subnets` are older names for the
    # AWS RDS database subnet groups in early versions of Provose.
    mysql_clusters__aws_db_subnet_group      = "mysql-subnets"
    postgresql_clusters__aws_db_subnet_group = "postgresql-subnets"
  }
}
