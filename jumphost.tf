data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource "aws_security_group" "jumphost" {
  count = var.jumphost != null ? 1 : 0

  name        = "jumphost-sg"
  description = "We are letting the world access our jumphost... with authorization"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Provose = var.name
  }
}

resource "aws_iam_role" "jumphost" {
  count = var.jumphost != null ? 1 : 0

  name_prefix           = "jumphost-iam-role"
  description           = "Designed to let our jumphost access basic parts of our cluster"
  assume_role_policy    = data.aws_iam_policy_document.ec2_assume_role_policy.json
  force_detach_policies = true
}

resource "aws_iam_instance_profile" "jumphost" {
  count = var.jumphost != null ? 1 : 0

  name_prefix = "jumphost-instance-profile"
  role        = aws_iam_role.jumphost[0].name
}

resource "aws_instance" "jumphost" {
  count = var.jumphost != null ? 1 : 0

  ami                         = data.aws_ami.amazon_linux_2_ecs_gpu_hvm_ebs.id
  instance_type               = var.jumphost.instance_type
  key_name                    = var.jumphost.key_name
  subnet_id                   = aws_subnet.vpc[0].id
  vpc_security_group_ids      = [aws_security_group.jumphost[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jumphost[0].id
  user_data                   = try(var.jumphost.user_data, null)
  tags = {
    Name    = "jumphost"
    Provose = var.name
  }
}

resource "aws_route53_record" "jumphost_public" {
  count   = var.jumphost != null ? 1 : 0
  zone_id = data.aws_route53_zone.external_dns.zone_id
  name    = "jumphost.${var.root_domain}"
  type    = "A"
  ttl     = "5"
  records = [aws_instance.jumphost[0].public_ip]

}

resource "aws_route53_record" "jumphost_private" {
  count = var.jumphost != null ? 1 : 0

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "jumphost.${var.internal_subdomain}"
  type    = "A"
  ttl     = "5"
  records = [aws_instance.jumphost[0].private_ip]
}

# == Output == 

output "jumphost" {
  value = {
    aws_security_group = {
      jumphost = aws_security_group.jumphost
    }
    aws_iam_role = {
      jumphost = aws_iam_role.jumphost
    }
    aws_iam_instance_profile = {
      jumphost = aws_iam_instance_profile.jumphost
    }
    aws_instance = {
      jumphost = aws_instance.jumphost
    }
    aws_route53_record = {
      jumphost_public  = aws_route53_record.jumphost_public
      jumphost_private = aws_route53_record.jumphost_private
    }
  }
}
