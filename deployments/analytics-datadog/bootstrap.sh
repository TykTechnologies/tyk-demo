#!/bin/bash

source scripts/common.sh
deployment="Analytics - Datadog"
log_start_deployment
bootstrap_progress

datadog_dashboard="https://app.datadoghq.com/dashboard/lists"


log_message "Stopping the Pump instance deployed by the base deployment"
# the tyk-pump container (from the tyk deployment) is stopped as it is replaced by the container from this deployment
command_docker_compose="$(generate_docker_compose_command) stop tyk-pump 2> /dev/null" 
eval $command_docker_compose
if [ "$?" != 0 ]; then
  echo "Error stopping Pump container"
  exit 1
fi
log_ok
bootstrap_progress

# verify tyk-pump container is stopped
log_message "Checking status of Pump container"
container_status=$(docker ps -a --filter "name=$(get_context_data "container" "pump" "1" "name")" --format "{{.Status}}")
log_message "  Pump container status is: $container_status"
if [[ $container_status != Exited* ]]
then
  log_message "  ERROR: tyk-pump container is not stopped. Exiting."
  exit 1
fi
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Analytics - Datadog
  ▽ Datadog
                    URL : $datadog_dashboard"
