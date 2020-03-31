resource "aws_security_group" "allow_all_egress_to_internet" {
  name        = "${var.name}/allow-all-egress-to-internet"
  vpc_id      = aws_vpc.vpc.id
  description = "Provose egress-only security group owned by module ${var.name}, allowing all outbound access to the Internet."

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Provose = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "vpc_ssh" {
  name        = "${var.name}/vpc-ssh"
  description = "Provose security group owned by module ${var.name}, allowing SSH access from within the VPC."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  tags = {
    Provose = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

# == Output ==

output "security_groups" {
  value = {
    aws_security_group = {
      allow_all_egress_to_internet = aws_security_group.allow_all_egress_to_internet
      vpc_ssh                      = aws_security_group.vpc_ssh
    }
  }
}
