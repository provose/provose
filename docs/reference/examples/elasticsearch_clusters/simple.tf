module "myproject" {
  source = "github.com/provose/provose?ref=v3.0.0"
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
  elasticsearch_clusters = {
    # This creates one Elasticsearch cluster named `ecsluster`
    escluster = {
      engine_version = "7.1"
      instances = {
        instance_type           = "t2.small.elasticsearch"
        instance_count          = 1
        storage_per_instance_gb = 20
      }
    }
  }
}
