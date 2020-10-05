---
title: Release notes
parent: Docs - v2.0 (LATEST)
nav_order: 1
---

# Provose v2.0 Release notes

Provose v2.0 is the second major release for Provose. In this release, we launched numerous new modules:
 - [`http_redirects`](../reference/http_redirects/) -- A way to program arbitrary HTTP redirects into the Application Load Balancer that Provose provides.
 - [`elastic_file_systems`](../reference/elastic_file_systems/) --  A fast and easy way to provision [AWS Elastic File System (EFS)](https://aws.amazon.com/efs/), which is Amazon's managed autoscaling filesystem for everyday workloads.
 - [`lustre_file_systems`](../reference/lustre_file_systems/) -- A fast and easy way to provision AWS FSx Lustre file systems, which is Amazon's managed offering for the high-performance Lustre filesystems, which is commonly used to store files for machine learning and high-performance computing workloads.
 - [`batch`](../reference/batch/) -- A module to configure AWS Batch Compute Environments, Job Queues, and Job Definitions.

We also replaced the v1 `ec2_instances` module with the following two modules:
 - [`ec2_on_demand_instances`](../reference/ec2_on_demand_instances/) -- A module to spin up regular ol' EC2 instances.
 - [`ec2_spot_instances`](../reference/ec2_spot_instances/) -- A module to spin up EC2 spot instances, which can be up to 80% percent cheaper than On-Demand instances.
 
 More information is available in the [changelog](/changelog/).
