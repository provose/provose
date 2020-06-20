output "instance_profiles" {
  value       = aws_iam_instance_profile.this
  description = "The AWS IAM instance profiles that we generated."
}