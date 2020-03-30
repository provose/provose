module "s3_cloudfront_website" {
  providers = {
    aws            = aws
    aws.acm_lookup = aws.acm_lookup
  }
  source = "./modules/s3_cloudfront_website"
  sites  = var.s3_cloudfront_website
}

# TODO: fill out the outputs for this submodule
