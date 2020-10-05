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
  batch = {
    "compute-environment-1" = {
      instances = {
        instance_types           = ["m5.large"]
        compute_environment_type = "SPOT"
        min_vcpus                = 0
        max_vcpus                = 2
      }
      job_queues = {
        "mainqueue" = {
          state    = "ENABLED"
          priority = 1
        }
      }
      job_definitions = {
        "job-1" = {
          image = {
            name             = "busybox"
            tag              = "latest"
            private_registry = false
          }
          vcpus   = 1
          memory  = 512
          command = ["echo", "hello", "world"]
          environment = {
            SOME_KEY = "some_var"
          }
        }
      }
    }
  }
}
