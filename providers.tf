terraform {
  required_providers {
    aws     = "2.54.0"
    null    = "2.1.2"
    tls     = "2.1.1"
    random  = "2.2.1"
    local   = "1.4.0"
    archive = "1.3.0"
  }
}

# TODO: There are many ways to authenticate to AWS. We should support them all.
provider "aws" {
  region                  = var.authentication.aws.region
  shared_credentials_file = var.authentication.aws.shared_credentials_file
  profile                 = var.authentication.aws.profile
}

# AWS Certificate Manager certifiates for CloudFront are always in us-east-1, no
# matter what AWS region the user is storing all of their other stuff in.
provider "aws" {
  alias                   = "acm_lookup"
  region                  = "us-east-1"
  shared_credentials_file = var.authentication.aws.shared_credentials_file
  profile                 = var.authentication.aws.profile
}
