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
  # Here, we create two Redis clusters named "cluster1" and "cluster2".
  redis_clusters = {
    # This cluster's DNS name is cluster1.production.example-internal.com
    cluster1 = {
      engine_version = "5.0.6"
      instances = {
        instance_type = "cache.t3.micro"
      }
    }
    # This cluster's DNS name is cluster2.production.example-internal.com
    cluster2 = {
      engine_version = "5.0.6"
      instances = {
        instance_type = "cache.m5.large"
      }
      # This means that changes to the cluster are applied in the next
      # mantenance window as opposed to immediately.
      apply_immediately = false
    }
  }
}
