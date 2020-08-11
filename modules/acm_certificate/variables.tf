variable "aws_route53_zone_id" {
  type        = string
  description = "THe ID for the AWS Route 53 Zone that contains the domain name that we want to make a certificate for. This cannot be a 'private' zone. The domain name has to be public in order for Amazon Certificate Manager to verify your ownership of it."
}

variable "dns_names" {
  type        = list(string)
  description = "A list of domain names (including subdomains) owned in your Amazon Web Services account that need an Amazon Certificate Manager certificates. One certificate name will be created with the first list item as the Common Name and the remainder as Alternate Names."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A mapping of Amazon tags to attach to the ACM certificate."
}
