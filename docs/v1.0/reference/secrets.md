---
title: secrets
parent: Reference v1.0
grand_parent: Docs - v1.0
search_exclude: true
---

# secrets

## Description

The Provose `secrets` module is a mapping of names to secret values. These are stored in Amazon Secrets Manager and can be accessed by containers deployed with the Provose [`containers` module](../containers/).

## Examples

This is an example of defining secrets with the Provose `secrets` module, and then consuming them in the [`containers` module](../containers/).

```terraform
{% include v1.0/reference/secrets/secrets.tf %}
```

## Inputs

A typical Provose secrets module configuration looks like

```terraform
secrets = {
    secret_name = "secret value as a string"
    other_secret_name = var.some_secret_variable
}
```

## Outputs

- `secrets.aws_secretsmanager_secret.secrets` -- This is a mapping of [`aws_secretsmanager_secret` resources](https://www.terraform.io/docs/providers/aws/r/secretsmanager_secret.html) for every secret specified.

- `secrets.aws_secretsmanager_secret_version.secrets` -- This is a mapping of [`aws_secretsmanager_secret_version` resources](https://www.terraform.io/docs/providers/aws/r/secretsmanager_secret_version.html) for every secret specified.
