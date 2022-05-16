terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "2.2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "4.14.0"
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
  aws_access_key = try(var.provose_config.authentication.aws.access_key, null)
  aws_secret_key = try(var.provose_config.authentication.aws.secret_key, null)
}

# TODO: There are many ways to authenticate to AWS. We should support them all.
provider "aws" {
  region     = try(var.provose_config.authentication.aws.region, null)
  access_key = local.aws_access_key
  secret_key = local.aws_secret_key
}

# AWS Certificate Manager certifiates for CloudFront are always in us-east-1, no
# matter what AWS region the user is storing all of their other stuff in.
provider "aws" {
  alias      = "acm_lookup"
  region     = "us-east-1"
  access_key = local.aws_access_key
  secret_key = local.aws_secret_key
}

locals {
  AWS_COMMAND = local.aws_access_key != null && local.aws_secret_key != null ? "AWS_ACCESS_KEY_ID='${local.aws_access_key}' AWS_SECRET_ACCESS_KEY_ID='${local.aws_secret_key}' aws --region ${data.aws_region.current.name} " : "aws --region ${data.aws_region.current.name} "

  # This is an environment variable dictionary that we can use with the local-exec provisioner.
  AWS_ENVIRONMENT = {
    AWS_ACCESS_KEY_ID        = local.aws_access_key
    AWS_SECRET_ACCESS_KEY_ID = local.aws_secret_key
    AWS_DEFAULT_REGION       = data.aws_region.current.name
  }
}
