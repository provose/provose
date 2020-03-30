resource "aws_security_group" "allow_all_egress_to_internet" {
  name   = "allow_all_egress_to_internet"
  vpc_id = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Powercloud = var.name
  }
}

resource "aws_security_group" "vpc_ssh" {
  name        = "${var.name}_vpc_ssh"
  description = "Enable SSH access from within the VPC."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  tags = {
    Powercloud = var.name
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
