module "myproject" {
  source = "github.com/provose/provose?ref=v2.0.0"
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
      # This spins up an additional `t2.small` EC2 instance running
      # a Logstash instance that will forward inputs to the `escluster`
      # Elasticsearch cluster.
      # You could connect to this Logstash instance on UDP port 5959
      # on escluster-logstash.production.example-internal.com
      logstash = {
        instance_type = "t2.small"
        key_name      = "james_laptop"
      }
    }
  }
}
