resource "aws_secretsmanager_secret" "secrets" {
  for_each                = var.secrets
  name                    = each.key
  recovery_window_in_days = 0
  tags = {
    Provose = var.provose_config.name
  }
}

resource "aws_secretsmanager_secret_version" "secrets" {
  for_each      = aws_secretsmanager_secret.secrets
  secret_id     = each.value.id
  secret_string = var.secrets[each.key]
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
