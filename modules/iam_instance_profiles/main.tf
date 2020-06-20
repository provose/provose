# Sometimes an interrupted `terraform destroy` command can leave an
# orphaned IAM instance profile. Running `terraform apply` again
# causes an `EntityAlreadyExists` error. Manually deleting the instance
# profile from the AWS console does not work. The instance profile
# has to be deleted from the command line.
#
# So this resource always attempts to delete the relevant AWS IAM
# instance profile before we attempt to create it. Hopefully this
# prevents more `EntityAlreadyExists` errors.
resource "null_resource" "this" {
  for_each = var.profile_configs
  provisioner "local-exec" {
    command = "${var.aws_command} iam delete-instance-profile --instance-profile-name '${each.value.instance_profile_name}' || true"
  }
}

resource "aws_iam_instance_profile" "this" {
  for_each = var.profile_configs
  name     = each.value.instance_profile_name
  path     = each.value.path
  role     = each.value.role_name
  depends_on = [
    null_resource.this
  ]
}
