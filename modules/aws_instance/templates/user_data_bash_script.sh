#!/bin/bash
set -Eeuxo pipefail
# Update yum and install Docker.
yum update -y
amazon-linux-extras install docker
systemctl start docker.service
usermod -a -G docker ec2-user
chkconfig docker on

%{ if ecs_cluster != null ~}
# Connect to an ECS cluster if we have one on deck.
echo ECS_CLUSTER=${ecs_cluster} >> /etc/ecs/ecs.config
echo ECS_BACKEND_HOST= >> /etc/ecs/ecs.config
%{ endif ~}

# Install EFS/NFS utils if we have them.
yum install -y amazon-efs-utils

echo "Powercloud setups complete. Handing over user_data setup to the user."
set +Eeuxo pipefail
${bash_user_data}
