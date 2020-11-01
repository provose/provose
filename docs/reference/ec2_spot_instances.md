---
title: ec2_spot_instances
parent: Reference
grand_parent: Docs
---

# ec2_spot_instances

## Description

The Provose `ec2_spot_instances` module enables the creation and deployment of Amazon EC2 Spot instances.

### How Spot instances work

The AWS documentation has more information about [how Spot instances work](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-instances.html). Unlike other AWS resources that Provose can provision for you, a Spot instance is not guaranteed to be provisioned and may be shut down by Amazon at any time.

### Should you use `ec2_spot_instances`?

If your application cannot tolerate the periodic shutdown of a Spot instance, you can provision an EC2 On-Demand instance instead with the [`ec2_on_demand_instances` module](../ec2_on_demand_instances/) instead.

If you are looking to deploy the same application across multiple services--perhaps behind an HTTP load balancer--you might find it handier to use the [`containers` module](../containers/) instead. You can get Spot pricing through the `containers` module by setting your `instance_type` to be `"FARGATE_SPOT"`. That does not work for this module, however.

## Examples

```terraform
{% include_relative examples/ec2_spot_instances/main.tf %}
```

## Inputs

The `ec2_spot_instances` module supports **all** of the same configuration key as the [`ec2_on_demand_instances` module](../ec2_on_demand_instances/), plus the following additional keys:

- `spot_price` -- **Optional.** The maximum price to request in the Spot market. If left blank, your maximum price will default to the On-Demand price. However, this does not mean that you _pay_ the On-Demand price.

- `spot_type` -- **Optional.** This value defaults to `"persistent"`, which means that AWS will resubmit the Spot request if the instance is terminated. You can set this value to `"one-time"` to close the Spot request when the instance is closed.

## Outputs

- `ec2_spot_instances.aws_security_group.ec2_spot_instances` -- A map with a key for every instance and every value is a Terraform [`aws_security_group`](https://www.terraform.io/docs/providers/aws/r/security_group.html) type.

- `ec2_spot_instances.aws_spot_instance_request.ec2_spot_instances` -- A map with the keys as the names of the Spot instances--dashed with a number if we set the `instances.instance_count` parameter to be greater than 1. Each value is a Terraform [`aws_spot_instance_request`](https://www.terraform.io/docs/providers/aws/r/spot_instance_request.html) type.

- `ec2_spot_instances.aws_route53_record.ec2_spot_instances` -- This is a mapping from the names EC2 Spot instances to the [`aws_route53_record` resource](https://www.terraform.io/docs/providers/aws/r/route53_record.html) that describes the DNS records internal to the VPC.
