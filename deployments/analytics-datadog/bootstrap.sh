#!/bin/bash

source scripts/common.sh
deployment="Analytics - Datadog"
log_start_deployment
bootstrap_progress

datadog_dashboard="https://app.datadoghq.com/dashboard/lists"
pump_container_name="$(get_context_data "container" "pump" "1" "name")"

log_message "Stopping the Pump container ($pump_container_name) deployed by the Tyk deployment. This prevents the Tyk deployment Pump from consuming the analytics records which we want to be processed by the Pump from this deployment."
command_docker_compose="$(generate_docker_compose_command) stop tyk-pump 2> /dev/null" 
eval $command_docker_compose
if [ "$?" != 0 ]; then
  echo "Error stopping Pump container $pump_container_name"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Verifying that $pump_container_name container is stopped"
container_status=$(docker ps -a --filter "name=$pump_container_name" --format "{{.Status}}")
log_message "  $pump_container_name container status is: $container_status"
if [[ $container_status != Exited* ]]
then
  log_message "  ERROR: $pump_container_name container is not stopped. Exiting."
  exit 1
fi
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Analytics - Datadog
  ▽ Datadog
                    URL : $datadog_dashboard"
