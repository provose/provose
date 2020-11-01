---
title: elasticsearch_clusters
parent: Reference
grand_parent: Docs
---

# elasticsearch_clusters

## Description

The Provose `elasticsearch_clusters` creates [Elasticsearch](https://www.elastic.co/) clusters on the [Amazon Elasticsearch Service](https://aws.amazon.com/elasticsearch-service/).

## Examples

### Running a single node of Elasticsearch 7.1 with Logstash

```terraform
{% include_relative examples/elasticsearch_clusters/simple.tf %}
```

## Inputs

- `engine_version` -- **Required.** The version of Elasticsearch to deploy, like `"7.4"`. You can find the currently-available versions of Elasticsearch [on the AWS website here](https://aws.amazon.com/elasticsearch-service/faqs/).

- `instances` -- **Required.** Settings for the instances running Elasticsearch.

  - `instance_type` -- **Required.** The Elasticsearch-specific instance type, such as `"t2.small.elasticsearch"`. You can find a list of supported instance types on the [AWS Elasticsearch service pricing page](https://aws.amazon.com/elasticsearch-service/pricing/).

  - `instance_count` -- **Required.** The number of instances to deploy for the Elasticsearch cluster.

  - `storage_per_instance_gb` -- **Required.** The amount of storage to provision--in gigabytes--for each instance in the cluster.

- `logstash` -- **Optional.** Optional settings to install Logstash on an EC2 instance that would write logs into the Elasticsearch cluster. [Logstash](https://www.elastic.co/logstash) is a data processing engine commonly used to format and redirect logs for indexing into Elasticsearch. It is not a required component to Elasticsearch, so Logstash configuration is purely optional. There are [more details below](#how-to-use-provose-to-deploy-logstash) about how to configure and use Logstash with Provose.

  - `instance_type` -- **Required.** The EC2 instance type to run Logstash on, like `"t2.small"`.

  - `key_name` -- **Optional.** The name of an AWS EC2 key pair that can be used to log into the Logstash instance.

## Outputs

- `elasticsearch_clusters.aws_security_group.elasticsearch` -- The AWS security group used to govern access to the Elasticsearch cluster.

- `elasticsearch_clusters.aws_elasticsearch_domain.elasticsearch` -- The `aws_elasticsearch_domain` object that defines the Elasticsearch cluster.

- `elasticsearch_clusters.aws_lb_listener_rule.elasticsearch` -- The listener rule for the AWS Application Load Balancer (ALB) that redirects DNS names to the cluster. This is for the VPC-only ALB that Provose provisions.

- `elasticsearch_clusters.aws_route53_record.elasticsearch` -- The Route 53 DNS record that gives a friendly DNS name to the Elasticsearch cluster.

- `elasticsearch_clusters.aws_route53_record.es_kibana` -- The Route 53 DNS record that gives a friendly DNS name to the Kibana endpoint.

## Implementation details

### How DNS works for Provose Elasticsearch clusters

The Amazon Elasticsearch service creates long and hard-to-remember names for clusters and their associated Kibana dashboards.

Provose sets up an internal Application Load Balancer to map an easy-to-remember DNS name name to the cluster. This DNS name, load balancer, Elasticsearch cluster, and Kibana dashboard is **not** available on the public Internet. For security reasons, they are all **only** available within the VPC that Provose creates for Elasticsearch cluster.

The internal Application Load Balance redirects requests to the Elasticsearch cluster or Kibana dashboard via an HTTP 301 redirect. Some Elasticsearch clients--such as the one Logstash uses--will treat the HTTP 301 code as an error as opposed to following the redirect. For these clients, you will need to use the DNS name for the Elasticsearch cluster or the Kibana dashboard set by AWS.

Provose also offers its own deployment of Logstash that is configured to work correctly with Provose's deployment of Elasticsearch.

### How to use Provose to deploy Logstash

The Provose `elasticsearch_clusters` module allows the provisioning of Logstash on an AWS EC2 instance. Logstash is a data processing engine used to commonly format and ingest logs for indexing into Elasticsearch. Logstash is not a required component to Elasticsearch, so Logstash configuration is purely optional.

This Logstash configuration is for development purposes only. It will not autoscale to large amounts of logs to be ingested.

If your `provose_config.internal_root_domain` is `"example.com"`, your `provose_config.internal_subdomain` is `"subdomain"`, and your Elasticsearch cluster name is `"cluster"`, then the Logstash DNS name is `"cluster-logstash.subdomain.example.com"` on UDP port 5959. Provose currently does not support advanced Logstash configurations. If you need that, you should consider running your own Logstash instance through either the Provose `ec2_instances` or `containers` modules.

### The differences between Amazon Elasticsearch Service and Elastic.co's Elasticsearch

Elasticsearch is an open-source search engine and database that is primarily maintained by the company Elastic NV.

Elastic has created various proprietary add-ons for Elasticsearch. These are generally not available on the AWS Elasticsearch Service. However, Amazon has developed many equivalent features and released them under the Apache 2.0 license as the [Open Distro for Elasticsearch](https://opendistro.github.io/for-elasticsearch/).

If the Open Distro does not fit your needs and you want to use Elastic's proprietary features, Provose's `elasticsearch_clusters` module will not be able to fulfill your needs.
