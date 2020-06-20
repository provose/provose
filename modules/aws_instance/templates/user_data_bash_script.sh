#!/bin/bash
set -Eeuxo pipefail

%{ if ecs_cluster != null ~}
# Connect to an ECS cluster if we have one on deck.
echo ECS_CLUSTER=${ecs_cluster} >> /etc/ecs/ecs.config
echo ECS_BACKEND_HOST= >> /etc/ecs/ecs.config
%{ endif ~}
set +Eeuxo pipefail
${bash_user_data}
