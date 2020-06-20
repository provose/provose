module "cloudfront_s3_websites" {
  providers = {
    aws            = aws
    aws.acm_lookup = aws.acm_lookup
  }
  source = "./modules/cloudfront_s3_websites"
  name   = var.provose_config.name
  sites  = var.cloudfront_s3_websites
}

# TODO: fill out the outputs for this submodule
