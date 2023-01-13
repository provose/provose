terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">=2.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.49"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.4"
    }
    local = {
      source  = "hashicorp/local"
      version = ">=2.3"
    }
  }
}

locals {
  AWS_COMMAND = "aws --region ${data.aws_region.current.name} "
}
