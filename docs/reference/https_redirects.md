---
search_exclude: true
title: https_redirects
parent: Reference
grand_parent: Docs
---

# https_redirects

## Description

The Provose `https_redirects` module is mapping of DNS names and settings on how to select redirects for them.

### What this module does

As the name suggests, this module can create HTTP 301 permanent redirects or HTTP 302 temporary redirects from all paths under a domain name to another. This module does not create DNS CNAME or other types of redirects.

You can use this module to redirect HTTP(S) traffic to anywhere on the Internet, but your AWS account must own the domain name for the source of the redirection.

### What this module does NOT do

This module redirects traffic with the public-facing Application Load Balancer (ALB), and currently cannot be used to route HTTP(S) traffic within the Virtual Private Cloud (VPC) that Provose sets up.

### How to configure this module

There are two _forwarding types_ that govern how the redirects work.

- `"DOMAIN_NAME"` -- This takes all HTTP(S) URLs under your source DNS name and forwards it to the corresponding location in the destination DNS name. For example, if your source name is `source.example.com` and you want to forward requests to `https://destination.com`, setting your `forwarding_type` to `"DOMAIN_NAME"` will send the URL `"https://source.example.com/some-path?q=a"` to `"https://destination.com?some-path?q=a"`.

- `"EXACT_URL"` -- This takes HTTP(S) URLs from the source and sends them to the exact same URL at the destination. For example, if your source name is `"source.example.com"` and you want to forward requests to `"https://destination.com"`, setting your `forwarding_type` to `"EXACT_URL"` will send `"https://source.example.com/some-path?q=a"`to `"https://destination.com"`. You can also set your destination to something like `"https://destination.com?some-path?q=a"` and all source URLs will go there.

## Examples

```terraform
{% include_relative examples/https_redirects/main.tf %}
```

## Inputs

- `destination` -- **Required.** This is the destination URL to send redirects to, like `https://example.com`. You should always include the protocol (like `"http"` or "`https"`). This can be an exact URL if the `forwarding_type` is `"EXACT_URL"`, or a generic domain name if the `forwarding_type` is `"DOMAIN_NAME"`.

- `forwarding_type` -- **Optional.** This specifies whether all possible sources are sent to corresponding destination URLs (`"DOMAIN_NAME"`) or whether to send them to the exact same destination URL (`"EXACT_URL"`).

- `status_code` -- **Optional.** This is the HTTP status code to use in the redirect. By default this is `301` making the redirect "permanent" in the eyes of web browsers, search engines, and other HTTP clients. You can set this to `302` to tell HTTP clients that the redirect is "temporary."

## Outputs
