output "aws_route53_zone" {
  description = "The `aws_route53_zone` data resource that we looked up,"
  value       = data.aws_route53_zone.main
}

output "wildcarded_dns_names" {
  description = "The wildcarded domain names that we requested ACM certificates for. Used for debugging."
  value       = local.wildcarded_dns_names
}

output "aws_acm_certificate" {
  description = "The Terraform `aws_acm_certificate` object that we created for the given domain names."
  value       = aws_acm_certificate.main
}

output "aws_route53_record" {
  description = "The Route 53 record used by ACM to validate ownership of our domain name."
  value       = aws_route53_record.main
}

output "aws_acm_certificate_validation" {
  description = "The certificate validation object for our new certificate."
  value       = aws_acm_certificate_validation.main
}