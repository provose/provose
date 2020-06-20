data "aws_route53_zone" "external_dns" {
  name         = "${var.provose_config.internal_root_domain}."
  private_zone = false
}

# == Output ==

output "external_dns" {
  value = {
    aws_route53_zone = {
      external_dns = data.aws_route53_zone.external_dns
    }
  }
}
