# This is the Terraform `random_password` resource that we use to generate secure random
# passwords for the AWS Aurora MySQL clusters that we provision below.
# You can read more about the provider here
# https://www.terraform.io/docs/providers/random/r/password.html
resource "random_password" "bigcluster_password" {
  # AWS RDS passwords must be between 8 and 41 characters
  length = 41
  # This is a list of special characters that can be included in the
  # password. This lits omits characters that often need to be
  # escaped.
  override_special = "()-_=+[]{}<>?"
}

# This is another  `random_password` resource that we use for the other cluster.
resource "random_password" "smallcluster_password" {
  length           = 41
  override_special = "()-_=+[]{}<>?"
}


module "myproject" {
  # These are various settings that are core to Provose.
  source = "github.com/provose/provose?ref=v2.0.0-beta5"
  provose_config = {
    authentication = {
      aws = {
        # Provose is going to pull AWS credentials from you environment.
        # If you want to specify your keys in code, you can set the
        # `access_key` and `secret_key` map keys here.
        region = "us-east-1"
      }
    }
    name                 = "myproject"
    internal_root_domain = "example-internal.com"
    internal_subdomain   = "myproject"
  }


  # These are two S3 buckets, which will be made available to one of the
  # below containers.
  s3_buckets = {
    "bucket-one.example-internal.com" = {
      versioning = false
    }
    "another-bucket.example-internal.com" = {
      versioning = true
    }
  }


  # These are Docker images that we upload to Elastic Container Registry (ECR).
  images = {
    # We build this container from a local path and upload it to the registry.
    "example/webserver" = {
      local_path = "../src/webserver"
    }
    # We create the ECR image repository for this container, but you need to
    # build and upload the image yourself.
    "example/anotherimage" = {}
  }


  # These are Aurora MySQL clusters.
  mysql_clusters = {
    # This creates an AWS Aurora MySQL cluster available
    # at the host bigcluster.myproject.example-internal.com.
    # This host is only available within the VPC.
    bigcluster = {
      engine_version = "5.7.mysql_aurora.2.08.0"
      database_name  = "exampledb"
      password       = random_password.bigcluster_password.result
      instances = {
        instance_type  = "db.r5.large"
        instance_count = 1
      }
    }
    # This creates a cluster at bigmy.production.example-internal.com.
    # This host is only available within the VPC.
    smallcluster = {
      engine_version = "5.7.mysql_aurora.2.08.0"
      database_name  = "otherdb"
      password       = random_password.smallcluster_password.result
      instances = {
        instance_type  = "db.t3.small"
        instance_count = 3
      }
    }
  }


  # These are names and values for secrets stored in AWS Secrets Manager.
  secrets = {
    bigcluster_password   = random_password.bigcluster_password.result
    smallcluster_password = random_password.smallcluster_password.result
  }


  # These are Docker containers that we run on AWS Elastic Container Service (ECS).
  # When `private_registry` is `true`, we access one of the images from the
  # ECR repositories defined above in the `images` section.
  # When `private_registry` is `false`, we look for publicly-available containers
  # on Docker Hub.
  containers = {
    # This is an example of a container that runs an image that we privately
    # built and uploaded to ECR.
    # We run the container on AWS Fargate--which means that there are no EC2
    # hosts exposed directly to the user.
    # The container is given access to one of the above MySQL
    # clusters via environment variables and the Secrets Manager.
    web = {
      image = {
        name             = "example/webserver"
        tag              = "latest"
        private_registry = true
      }
      public = {
        https = {
          internal_http_port              = 8000
          internal_http_health_check_path = "/"
          public_dns_names                = ["web.test.example.com"]
        }
      }
      instances = {
        instance_type   = "FARGATE"
        container_count = 10
        cpu             = 256
        memory          = 512
      }
      environment = {
        MYSQL_HOST     = "bigcluster.myproject.example-internal.com"
        MYSQL_USER     = "root"
        MYSQL_DATABASE = "exampledb"
        MYSQL_PORT     = 3306
      }
      secrets = {
        MYSQL_PASSWORD = "bigcluster_password"
      }
    }
    # This is an example of a container that runs a publicly-available
    # image from Docker Hub on a few `t2.small` EC2 instances.
    helloworld = {
      image = {
        name             = "nginxdemos/hello"
        tag              = "latest"
        private_registry = false
      }
      public = {
        https = {
          internal_http_port              = 80
          internal_http_health_check_path = "/"
          public_dns_names                = ["helloworld.example.com"]
        }
      }
      instances = {
        instance_type   = "t2.small"
        container_count = 4
        instance_count  = 2
        cpu             = 256
        memory          = 512
      }
    }
  }
}
