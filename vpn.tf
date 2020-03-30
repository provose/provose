/* IMPORTANT NOTE:
* Because this module uses the Terraform `tls` module to generate keys
* as opposed to an external key-generating program like OpenVPN EasyRSA,
* the private keys are stored in Terraform state. Read more at
* https://www.terraform.io/docs/providers/tls/index.html
* 
* Because of this, it is important to use Provose with a Terraform state
* backend that can be considered to be reasonably secure--e.g. an encrypted
* Amazon S3 bucket with strict access controls.
*/

locals {
  /* I think there is some issue with importing and using ECDSA
   * certificates into AWS ACM. Otherwise ECDSA would be prefereable
   * for performance reasons. */
  key_algorithm = "RSA"
  /* UDP is typically the default for OpenVPN and performs better,
   * but a TCP TLS port 443 VPN is the easiest to sneak past corporate
   * firewalls. */
  transport_protocol = try(var.vpn.transport_protocol, "tcp")
  /* By default, we usually want to have a split tunnel VPN because we 
  * do not want to slow down the user's Internet-browsing experience by
  * routing all of their traffic through AWS.
  * 
  * We also run into the issue where various websites block traffic from
  * the AWS IP ranges in order to block bots or scrapers.
  */
  split_tunnel = try(var.vpn.split_tunnel, true)
}

## CERTIFICATE AUTHORITY
resource "tls_private_key" "vpn__ca" {
  count     = var.vpn != null ? 1 : 0
  algorithm = local.key_algorithm
  lifecycle {
    create_before_destroy = true
  }
}

resource "tls_self_signed_cert" "vpn__ca" {
  count             = var.vpn != null ? 1 : 0
  is_ca_certificate = true
  key_algorithm     = tls_private_key.vpn__ca[count.index].algorithm
  private_key_pem   = tls_private_key.vpn__ca[count.index].private_key_pem
  subject {
    common_name = "ca.vpn.${var.internal_subdomain}.${var.root_domain}"
  }
  set_subject_key_id = true
  # valid for 10 years
  validity_period_hours = 24 * 365.25 * 10
  # early renewal after 1 year
  early_renewal_hours = 24 * 365
  allowed_uses = [
    "any_extended",
    "digital_signature",
    "key_encipherment",
    "key_agreement",
    "cert_signing",
    "crl_signing",
    "server_auth"
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "vpn__ca" {
  count            = var.vpn != null ? 1 : 0
  private_key      = tls_private_key.vpn__ca[count.index].private_key_pem
  certificate_body = tls_self_signed_cert.vpn__ca[count.index].cert_pem
  tags = {
    Provose = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

## SERVER

resource "tls_private_key" "vpn__server" {
  count     = var.vpn != null ? 1 : 0
  algorithm = local.key_algorithm
  lifecycle {
    create_before_destroy = true
  }
}

resource "tls_cert_request" "vpn__server" {
  count           = var.vpn != null ? 1 : 0
  key_algorithm   = tls_private_key.vpn__server[count.index].algorithm
  private_key_pem = tls_private_key.vpn__server[count.index].private_key_pem
  subject {
    common_name = "server.vpn.${var.internal_subdomain}.${var.root_domain}"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "tls_locally_signed_cert" "vpn__server" {
  count              = var.vpn != null ? 1 : 0
  cert_request_pem   = tls_cert_request.vpn__server[count.index].cert_request_pem
  ca_key_algorithm   = tls_private_key.vpn__ca[count.index].algorithm
  ca_private_key_pem = tls_private_key.vpn__ca[count.index].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vpn__ca[count.index].cert_pem
  set_subject_key_id = true
  # valid for 10 years
  validity_period_hours = 24 * 365.25 * 10
  # early renewal after 1 year
  early_renewal_hours = 24 * 365
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth"
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "vpn__server" {
  count             = var.vpn != null ? 1 : 0
  private_key       = tls_private_key.vpn__server[count.index].private_key_pem
  certificate_body  = tls_locally_signed_cert.vpn__server[count.index].cert_pem
  certificate_chain = tls_self_signed_cert.vpn__ca[count.index].cert_pem
  tags = {
    Provose = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

# CLIENTS

resource "tls_private_key" "vpn__clients" {
  for_each  = try(var.vpn.clients, {})
  algorithm = local.key_algorithm
}

resource "tls_cert_request" "vpn__clients" {
  for_each        = tls_private_key.vpn__clients
  key_algorithm   = each.value.algorithm
  private_key_pem = each.value.private_key_pem
  subject {
    common_name = "${each.key}.client.vpn.${var.internal_subdomain}.${var.root_domain}"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "tls_locally_signed_cert" "vpn__clients" {
  for_each           = tls_cert_request.vpn__clients
  cert_request_pem   = each.value.cert_request_pem
  ca_key_algorithm   = tls_private_key.vpn__ca[0].algorithm
  ca_private_key_pem = tls_private_key.vpn__ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vpn__ca[0].cert_pem
  set_subject_key_id = true
  # valid for 10 years
  validity_period_hours = 24 * 365.25 * 10
  # early renewal after 1 year
  early_renewal_hours = 24 * 365
  allowed_uses = [
    "digital_signature",
    "key_agreement"
  ]
  lifecycle {
    create_before_destroy = true
  }
}

# CLOUDWATCH

resource "aws_cloudwatch_log_group" "vpn" {
  count = var.vpn != null ? 1 : 0
  name  = "${var.name}-vpn-logs-group"
}

resource "aws_cloudwatch_log_stream" "vpn" {
  count          = var.vpn != null ? 1 : 0
  name           = "${var.name}-vpn-logs-stream"
  log_group_name = aws_cloudwatch_log_group.vpn[count.index].name
}

resource "aws_ec2_client_vpn_endpoint" "vpn" {
  count                  = var.vpn != null ? 1 : 0
  description            = "Provose Management VPN"
  split_tunnel           = local.split_tunnel
  transport_protocol     = local.transport_protocol
  server_certificate_arn = aws_acm_certificate.vpn__server[count.index].arn
  client_cidr_block      = cidrsubnet(aws_vpc.vpc.cidr_block, 3, length(aws_subnet.vpc))

  dns_servers = [cidrhost(aws_vpc.vpc.cidr_block, 2)]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.vpn__ca[count.index].arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.vpn[count.index].name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.vpn[count.index].name
  }

  tags = {
    Name    = "${var.name}-vpn"
    Provose = var.name
  }
}

# VPN CONFIG

resource "aws_ec2_client_vpn_network_association" "vpn" {
  count                  = var.vpn != null ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn[count.index].id
  subnet_id              = aws_subnet.vpc[0].id
}

# This piece of code is borrowed from:
# https://github.com/terraform-providers/terraform-provider-aws/issues/7494
# Also read:
# https://docs.aws.amazon.com/cli/latest/reference/ec2/authorize-client-vpn-ingress.html
# and
# https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_AuthorizeClientVpnIngress.html
resource "null_resource" "vpn__ingress" {
  count = var.vpn != null ? 1 : 0
  provisioner "local-exec" {
    command = "aws --region ${data.aws_region.current.name} ec2 authorize-client-vpn-ingress --client-vpn-endpoint-id ${aws_ec2_client_vpn_endpoint.vpn[0].id} --target-network-cidr 0.0.0.0/0 --authorize-all-groups"
  }
  depends_on = [
    aws_ec2_client_vpn_endpoint.vpn
  ]
}
locals {
  dhcp_options = join("\n", [
    for server in try(aws_ec2_client_vpn_endpoint.vpn[0].dns_servers, []) :
    "dhcp-option DNS ${server}"
    ]
  )
}
resource "local_file" "vpn__clients_ovpn" {
  for_each          = tls_locally_signed_cert.vpn__clients
  filename          = "${try(var.vpn.ovpn_dir, ".")}/${each.key}.ovpn"
  file_permission   = "0600"
  sensitive_content = <<EOF
# OpenVPN client config for user `${each.key}` and module ${var.name}
client
dev tun
proto ${local.transport_protocol}
remote ${trimprefix(aws_ec2_client_vpn_endpoint.vpn[0].dns_name, "*.")} 443
remote-random-hostname
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
verb 3
reneg-sec 0
<ca>
${tls_self_signed_cert.vpn__ca[0].cert_pem}
</ca>
<cert>
${tls_locally_signed_cert.vpn__clients[each.key].cert_pem}
</cert>
<key>
${tls_private_key.vpn__clients[each.key].private_key_pem}
</key>
EOF
}

# == Output ==

output "vpn" {
  value = {
    tls_private_key = {
      vpn__ca      = tls_private_key.vpn__ca
      vpn__server  = tls_private_key.vpn__server
      vpn__clients = tls_private_key.vpn__clients
    }
    tls_self_signed_cert = {
      vpn__ca = tls_self_signed_cert.vpn__ca
    }
    aws_acm_certificate = {
      vpn__ca     = aws_acm_certificate.vpn__ca
      vpn__server = aws_acm_certificate.vpn__server
    }
    tls_cert_request = {
      vpn__server  = tls_cert_request.vpn__server
      vpn__clients = tls_cert_request.vpn__clients
    }
    tls_locally_signed_cert = {
      vpn__server  = tls_locally_signed_cert.vpn__server
      vpn__clients = tls_locally_signed_cert.vpn__clients
    }
    aws_cloudwatch_log_group = {
      vpn = aws_cloudwatch_log_group.vpn
    }
    aws_cloudwatch_log_stream = {
      vpn = aws_cloudwatch_log_stream.vpn
    }
    aws_ec2_client_vpn_endpoint = {
      vpn = aws_ec2_client_vpn_endpoint.vpn
    }
    aws_ec2_client_vpn_network_association = {
      vpn = aws_ec2_client_vpn_network_association.vpn
    }
    null_resource = {
      vpn__ingress = null_resource.vpn__ingress
    }
    local_file = {
      vpn__clients_ovpn = local_file.vpn__clients_ovpn
    }
  }
}
