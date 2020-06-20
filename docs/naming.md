---
title: DNS and naming conventions
nav_order: 6
---

# DNS and naming conventions

Provose requires a domain name in your AWS account to serve as the root domain name for internal services. This domain name is used as Common Name in the TLS certificates used to secure internal communications. This root domain is specified in the configuration `provose_config.internal_root_domain`.

To enable multiple instances of Provose to share the same root domain, each Provose instance uses different subdomains, which is specified in `provose_config.internal_subdomain`. Provose sets up DNS names for services as subdomains of this internal subdomain.

The below example is an abbreviated version of a configuration that would create four services available within the VPC:

- A Redis instance at `redis1.production.example-internal.com`
- A Redis instance at `redis2.production.example-internal.com`
- A PostgreSQL cluster at `pg1.production.example-internal.com`
- A PostgreSQL cluster at `pg2.production.example-internal.com`
- A Redis instance at `redis1.testing.example-internal.com`
- A Redis instance at `redis2.testing.example-internal.com`
- An Elasticsearch cluster at `elastic1.testing.example-internal.com`
- An Elasticsearch cluster at `elastic2.testing.example-internal.com`

```terraform
module "example1" {
  source = "github.com/provose/provose?ref=v1.0.0"
  provose_config = {
    authentication = {
        ...
    }
    name                 = "example1"
    internal_root_domain = "example-internal.com"
    internal_subdomain   = "production"
  }
  # Here, we create two Redis clusters named `redis1` and `redis2`.
  redis_clusters = {
    # This Redis cluster's DNS name is `redis1.production.example-internal.com`.
    redis1 = {
      # fill out config here
    }
    # This Redis cluster's DNS name is `redis2.production.example-internal.com`.
    redis2 = {
      # fill out config here
    }
  }
  postgresql_clusters = {
    # This PostgreSQL cluster's DNS name is `pg1.production.example-internal.com`.
    pg1 = {
      # fill out config here
    }
    # This PostgreSQL cluster's DNS name is `pg2.production.example-internal.com`.
    pg2 = {
      # fill out config here
    }
  }
}

module "example2" {
  source = "github.com/provose/provose?ref=v1.0.0"
  provose_config = {
    authentication = {
        ...
    }
    name                 = "example2"
    internal_root_domain = "example-internal.com"
    internal_subdomain   = "staging"
  }
  # Here, we create two Redis clusters named `redis1` and `redis2`.
  redis_clusters = {
    # This cluster's DNS name is `redis1.staging.example-internal.com`.
    redis1 = {
      # fill details here...
    }
    # This cluster's DNS name is `redis2.staging.example-internal.com`.
    redis2 = {
      # fill details here...
    }
  }
  # Here, wqe create two Elasticsearch clusters named `elastic1` and `elastic2`.
  elasticsearch_clusters = {
    # This Elasticsearch cluster's DNS name is `elastic1.staging.example-internal.com`.
    elastic1 = {
      # fill details here...
    }
    # This Elasticsearch cluster's DNS name is `elastic2.staging.example-internal.com`.
    elastic2 = {
      # fill details here...
    }
  }
}
```
