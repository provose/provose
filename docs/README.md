# Provose Documentation

This repository is a Jekyll static website that contains the documentation for the [Provose](https://github.com/provose/provose) Terraform module.

# Contribution guidelines

## Terraform examples

All Terraform examples should be placed as separate `.tf` files in the `_includes` directory, and then accessed with a Jekyll `include` command line:

```
{% include path/to/terraform/file.tf %}
```

where the path excludes the `_include` file.

We should regularly run `terraform fmt -recursive _includes/` to appropriately format the Terraform example files and check for errors.
