---
title: lustre_file_systems
parent: Reference
grand_parent: Docs
---

# lustre_file_systems

## Description

This Provose configuration sets up AWS FSx Lustre clusters. Lustre is a high-performance networked filesytem commonly used in supercomputing. AWS FSx Lustre is Amazon Web Services' managed Lustre offering.

AWS FSx Lustre is appropriate for compute workloads that require large amounts of data and would otherwise be I/O-bound. For example, terabyte-scale machine learning typically requires fast storage, and FSx Lustre is a popular choice.

### Beware of long timeouts and "tainting"

AWS FSx Lustre clusters can take a long time to deploy--even multiple hours. By default, Terraform will wait 30 minutes before timing out. When this happens, you should use the AWS Web Console or the command line to check the status of your cluster. When you see a timeout from Terraform, you should **not** rerun Terraform before the cluster has finished deploying, otherwise this will destroy your cluster.

When your cluster has finished deploying, Terraform might consider it *"tainted"* because it timed out during the cluster's creation. However, in all likelihood, your cluster is most likely fine. If Terraform says something like 

```
# module.{your-module-name}.aws_fsx_lustre_file_system.lustre_file_systems["{your-cluster-name}"] is tainted, so must be replaced
```
then run this command:

```
terraform untaint 'module.{your-module-name}.aws_fsx_lustre_file_system.lustre_file_systems["{your-cluster-name}"]'
```
with replacing `{your-module-name}` and `{your-cluster-name}` as appropriate. Make sure to wrap your resource name in single quotes (`'`) to prevent your shell from interpreting the `[`, `]`. and `"` characters.

## Examples

```terraform
{% include_relative examples/lustre_file_systems/example_one.tf %}
```

## Inputs

- `deployment_type` -- **Required.** The filesystem deployment type. Currently this can be one of the following values. The [AWS documentation has more information](https://aws.amazon.com/blogs/aws/amazon-fsx-for-lustre-persistent-storage/) about the differences between the deployment types.

  - `"SCRATCH_1"` -- The original storage type for AWS FSx Lustre. This is typically used for storing temporary data and intermediate computations. This storage type is not replicated, which makes it less reliable for long-term storage.

  - `"SCRATCH_2"` -- A scratch storage type with a much higher burst speed. This is also not replicated.

  - `"PERSISTENT_1"` -- A storage type that offers replication in the same Availability Zone (AZ), which makes it more appropriate for long-term storage.

- `storage_capacity_gb` -- **Required.** This is the total storage capacity of the Lustre cluster in gibibytes. The minimum value is 1200, which is about 1.2 tebibytes. The next valid value is 2400. From there, the valid capacity values go up in increments of 2400 for the `"PERSISTENT_1"` and `"SCRATCH_2"` types, and in increments of 3600 for the `"SCRATCH_1"` type.

- `per_unit_storage_throughput_mb_per_tb` -- **Optional.** This field is required only for the `"PERSISTENT_1"` `deployment_type`. It describes the throughput speed _per tebibyte_ of provisioned storage. Valid values are 50, 100, and 200. More information about this key can be found under [PerUnitStorageThroughput in the AWS documentation](https://docs.aws.amazon.com/fsx/latest/APIReference/API_CreateFileSystemLustreConfiguration.html).

- `s3_import_path` -- **Optional.** If entered, this is an Amazon S3 path that can be used as a data repository for importing data into the Lustre cluster.

- `s3_export_path` -- **Optional.** If entered, this is an Amazon S3 path that the Lustre cluster will export to.

- `auto_import_policy` -- **Optional.** If you have specified `s3_import_path` to import data from an S3 bucket into your Lustre filesystem, you can set the following options for importing new data:

  - `"NONE"` -- This is the default value. AWS will not update your Lustre cluster with files created or changed after the Lustre cluster is created.

  - `"NEW"` -- This setting will automatically import new files from S3 into Lustre, but **not** changed files or deletions.

  - `"NEW_CHANGED"` -- This setting will automatically import new files and changed files. Files deleted from S3 will **not** be deleted in Lustre.

- `imported_file_chunk_size_mb` -- **Optional.** This value can be set if `s3_import_path` is set. It determines the stripe count and the maximum amount of data--in mebibytes--that can be located on a single physical disk. This value defaults to 1024, but can be set to any value between 1 and 512000 inclusive.

## Outputs

- `lustre_file_systems.aws_security_group.lustre_file_systems` -- This is a mapping between the cluster namd and the underlying [`aws_security_group` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/security_group). The security group opens up this filesystem to all traffic in the containing VPC.

- `lustre_file_systems.aws_fsx_lustre_file_system.lustre_file_systems` -- This is a mapping between the cluster name and the underlying [`aws_fsx_lustre_filesystem` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/fsx_lustre_file_system)

- `lustre_file_systems.aws_route53_record.lustre_file_systems` -- This is a mapping between the cluster name and the underlying [`aws_route53_record` resource](https://registry.terraform.io/providers/hashicorp/aws/3.0.0/docs/resources/route53_record).
