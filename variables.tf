terraform {
  # Optional attributes and the defaults function are
  # both experimental, so we must opt in to the experiment.
  experiments = [module_variable_optional_attrs]
}

variable "batch" {
  type        = any
  default     = {}
  description = "Sets up AWS Batch configuration."
}

variable "certificates" {
  type = map(object({
    domain_name               = string,
    subject_alternative_names = optional(list(string)),
  }))
  default     = {}
  description = "Sets up TLS certificates using Amazon Certificate Manager (ACM)."
}

variable "containers" {
  type        = any
  default     = {}
  description = "Sets up containers on Elastic Container Service. This abstracts over ECS clusters, services, task definitions, and tasks."
}

variable "ebs_volumes" {
  type        = any
  default     = {}
  description = "Creates Elastic Block Storage volumes that are independent of an AWS EC2 instance, but can be bound to one."
}

variable "ec2_instances" {
  type        = any
  default     = null
  description = "Sets up bare AWS EC2 instances."

  validation {
    condition     = var.ec2_instances == null
    error_message = "The `ec2_instances` module has been deprecated since Provose 2.0. Please migrate to the `ec2_on_demand_instances` module."
  }
}

variable "ec2_on_demand_instances" {
  type        = any
  default     = {}
  description = "Sets up bare AWS EC2 On-Demand instances."

  validation {
    condition = !contains([
      for instance_config in var.ec2_on_demand_instances :
      instance_config.instances.instance_type != "FARGATE"
    ], false)
    error_message = "You cannot use the \"FARGATE\" instance type when provisioning an EC2 instance. You can only use that with the `containers` module."
  }

  validation {
    condition = !contains([
      for instance_config in var.ec2_on_demand_instances :
      !can(instance_config.spot_price)
    ], false)
    error_message = "You cannot specify a Spot price with an EC2 On-Demand instance. You are probably looking to use the `ec2_spot_instances` key instead."
  }

  validation {
    condition = !contains([
      for instance_config in var.ec2_on_demand_instances :
      !can(instance_config.spot_type)
    ], false)
    error_message = "You cannot specify a Spot type with an EC2 On-Demand instance. You are probably looking to use the `ec2_spot_instances` key instead."
  }
}

variable "ec2_spot_instances" {
  type        = any
  default     = {}
  description = "Sets up bare AWS Spot instances."

  validation {
    condition = !contains([
      for instance_config in var.ec2_spot_instances :
      instance_config.instances.instance_type != "FARGATE"
    ], false)
    error_message = "You cannot use the \"FARGATE\" instance type when provisioning an EC2 instance. You can only use that with the `containers` module."
  }
}

variable "elastic_file_systems" {
  type        = any
  default     = {}
  description = "Sets up AWS Elastic File Systems (EFS), which are Network File System (NFS) instances managed by Amazon."
}

variable "elasticsearch_clusters" {
  type        = any
  default     = {}
  description = "Sets up Elasticsearch clusters with Kibana using Amazon's managed offering for Elasticsearch."
}

variable "https_redirects" {
  type        = any
  default     = {}
  description = "Sets up HTTP(S) 301 or 302 redirects using the Application Load Balancer shared by every instance of Provose. You must own the source domain name in your AWS account, but the destination domain name can be anywhere on the Internet."
}

variable "images" {
  type        = any
  default     = {}
  description = "Sets up images on AWS's Elastic Container Registry."
}
variable "lustre_file_systems" {
  type        = any
  default     = {}
  description = "Sets up an AWS FSx managed Lustre distributed filesystem."
}

variable "mysql_clusters" {
  type        = any
  default     = {}
  description = "Sets up AWS Aurora MySQL clusters."
}

variable "overrides" {
  type        = any
  default     = {}
  description = "Manual overrides for compatibility."
}

variable "postgresql_clusters" {
  type        = any
  default     = {}
  description = "Sets up AWS Aurora PostgreSQL clusters."
}

variable "provose_config" {
  type        = any
  description = "Required field. This sets up the core configuration of Provose."
}

variable "redis_clusters" {
  type        = any
  default     = {}
  description = "Sets up AWS ElastiCache Redis clusters."
}

variable "s3_buckets" {
  type        = any
  default     = {}
  description = "Sets up AWS S3 buckets."
}

variable "secrets" {
  type        = map(any)
  default     = {}
  description = "This is a mapping of secrets to values. The secrets are stored in AWS Secrets Manager."
}