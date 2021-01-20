---
title: source
parent: Reference
grand_parent: Docs
---

# source

## Description

The `source` parameter is used in Terraform modules to describe where to find the module.

When using Provose, you should set `source` to be `"github.com/provose/provose?ref=v3.0.0"`. Always make sure that the `ref=` parameter is pinned to a specific version to avoid Provose upgrading without your intention.

If you want to make modifications to Provose and use them, you should clone the Provose repository on GitHub with with shell command `git clone --recurse-submodules https://github.com/provose/provose.git`. After that, you can set the `source` parameter to be the local filesystem path where you cloned the repository.

THe `source` parameter comes from Terraform's underlying module syntax--not Provose itself. The Terraform documentation has more information about [how to specify `source` in a module configuration](https://www.terraform.io/docs/modules/sources.html).

## Examples

```terraform
{% include_relative examples/source/source.tf %}
```

## Inputs

The value for the `source` parameter is just a string that points at the online repository or filesystem path. This parameter is not a mapping.

## Outputs

There are no outputs for the `source` parameter.
