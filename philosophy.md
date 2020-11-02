---
title: Philosophy
nav_order: 5
---

# Provose's design philosophy

These are some of the design principles we consider when setting some of Provose's intelligent defaults. Configuring AWS infrastructure is difficult because of the sheer number of settings needed to make a production configuration. Tools like Terraform and CloudFormation expose the full complexity of the cloud for advanced users, but Provose's goal is to make everything simpler.

## Provose favors immediacy, not maintenance windows.

By default, Terraform schedules many changes for various resources--like RDS, ElastiCache, and DocumentDB--for the resource's next maintenance window. Provose's default is the opposite and changes are applied to resources immediately. However, this triggers a small amount of downtime, and this behavior can typically be disabled by setting the `apply_immediately` flag to `false` when applicable.

When `apply_immediately` is set to `false` on a database, that means changes to it will be made during the next maintenance window.

## Provose favors affordability over scalability

Some of Provose's pre-packaged configurations cannot be easily configured to autoscale to high loads, but they have been designed to use cloud resources economically at small scales. This is because Provose is appropriate for running many small-scale experiments in the cloud without breaking the bank, and in many cases scalability engineering requies domain expertise that a library like Provose would be unable to provide.

Furthermore, it is important that Provose's defaults are not needlessly expensive for most users. Cloud computing can become expensive, and cheap defaults are important.

## Provose standardizes on x86_64 Amazon Linux 2 on Amazon Web Services

There are other architectures, other AMIs, and other cloud provider, but in an effort to reduce the surface area for debugging, Provose will limit itself to running software on x86_64 Amazon Linux 2 instances on Amazon Web Services, although we do use [custom Amazon Machine Images](/amazon-machine-images-amis/).
