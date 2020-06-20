resource "aws_security_group" "allow_all_egress_to_internet__new" {
  name                   = "P/v1/${var.provose_config.name}/allow_all_egress_to_internet"
  vpc_id                 = aws_vpc.vpc.id
  description            = "Provose egress-only security group owned by module ${var.provose_config.name}, allowing all outbound access to the Internet."
  revoke_rules_on_delete = true
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_security_group" "vpc_ssh" {
  name                   = "P/v1/${var.provose_config.name}/vpc_ssh"
  description            = "Provose security group owned by module ${var.provose_config.name}, allowing SSH access from within the VPC."
  vpc_id                 = aws_vpc.vpc.id
  revoke_rules_on_delete = true
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  tags = {
    Provose = var.provose_config.name
  }
}

# == Output ==

output "security_groups" {
  value = {
    aws_security_group = {
      allow_all_egress_to_internet = aws_security_group.allow_all_egress_to_internet__new
      vpc_ssh                      = aws_security_group.vpc_ssh
    }
  }
}
