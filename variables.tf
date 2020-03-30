variable "authentication" {
  type = any
}

variable "name" {
  type = string
}

variable "description" {
  type = string
}

variable "aws_vpc_cidr" {
  type        = string
  description = "The CIDR of the AWS VPC"
  default     = "10.0.0.0/16"
}

variable "root_domain" {
  type = string
}

variable "internal_subdomain" {
  type        = string
  description = "The subdomain of the `root_domain` that is the base for the URL of all internal services."
  default     = "internal"
}

variable "secrets" {
  type    = map
  default = {}
}

variable "s3_cloudfront_website" {
  type    = any
  default = {}
}

variable "statsd_graphite_grafana" {
  type    = any
  default = null
}

variable "aws_instance" {
  type    = any
  default = {}
}

variable "container" {
  type    = any
  default = {}
}

variable "elasticsearch" {
  type    = any
  default = {}
}

variable "ebs_volume" {
  type    = any
  default = {}
}

variable "redis" {
  type    = any
  default = {}
}

variable "mysql" {
  type    = any
  default = {}
}

variable "postgresql" {
  type    = any
  default = {}
}

variable "jumphost" {
  type    = map
  default = null
}

variable "redisinsight" {
  type    = map
  default = null
}

variable "vpn" {
  type        = any
  description = "Settings for the Client VPN."
  default     = null
}

variable "s3" {
  type        = any
  description = "S3 buckets"
  default     = {}
}

variable "sentry" {
  type        = any
  description = "Configuration for on-prem Sentry"
  default     = null
}
