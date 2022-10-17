terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "2.2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "4.35.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.2.2"
    }
  }
}

locals {
  AWS_COMMAND = "aws --region ${data.aws_region.current.name} "
}


# THIS PROVIDER IS DEPRECATED. DO NOT REFERENCE IT IN OTHER CODE.
# This provider is here for long-time Provose users who have
# resources that depend on this provider.
# Originally, this provider was used for looking up CloudFront certificate information
# in us-east-1.
provider "aws" {
  alias  = "acm_lookup"
  region = "us-east-1"
}
