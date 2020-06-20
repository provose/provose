variable "aws_command" {
  description = "The shell command used to run the AWS CLI--including environment variable declarations."
  type        = string
  default     = "aws"
}

variable "profile_configs" {
  description = "A map where the keys are instance profile names and values are  describing AWS IAM instance profiles."
  type = map(object({
    instance_profile_name = string,
    path                  = string,
    role_name             = string,
  }))
}