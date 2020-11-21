resource "aws_secretsmanager_secret" "secrets" {
  for_each                = var.secrets
  name                    = each.key
  recovery_window_in_days = 0
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_secretsmanager_secret_version" "secrets" {
  for_each = {
    for key, secret in aws_secretsmanager_secret.secrets :
    key => {
      secret_id     = secret.id
      secret_string = var.secrets[key]
    }
    if contains(keys(var.secrets), key)
  }
  secret_id     = each.value.secret_id
  secret_string = each.value.secret_string
}

# == Output ==

output "secrets" {
  value = {
    aws_secretsmanager_secret = {
      secrets = aws_secretsmanager_secret.secrets
    }
    aws_secretsmanager_secret_version = {
      secrets = aws_secretsmanager_secret_version.secrets
    }
  }
}
