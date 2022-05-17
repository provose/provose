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
    internal_subdomain   = "myproject"
  }
  # Here we create an AWS S3 bucket that we will use as the data repository
  # for our Lustre cluster. Data repositories are not necessary if you want
  # to spin up an empty Lustre cluster.
  s3_buckets = {
    "mydata.myproject.example-internal.com" = {
      versioning = false
    }
  }
  lustre_file_systems = {
    mydatacache = {
      # SCRATCH_2 clusters are appropriate for when you need fast reads and writes,
      # but do not need automated replication. If you want higher guarantees of
      # persistence, use the "PERSISTENT" deployment type.
      deployment_type = "SCRATCH_2"

      # Currently this is the smallest storage size that can be deployed.
      storage_capacity_gb = 12000

      # Here we specify the S3 bucket and key prefix for loading into this
      # cluster. These can be set to different paths, but if they are set to the
      # same path, then writes to these files in Lustre will be written back
      # to S3.
      s3_import_path = "s3://mydata.myproject.example-internal.com/prefix/"
      s3_export_path = "s3://mydata.myproject.example-internal.com/prefix/"
    }
  }
}
