#!/bin/bash

source scripts/common.sh
deployment="Analytics - Datadog"
log_start_deployment
bootstrap_progress

datadog_dashboard="https://app.datadoghq.com/dashboard/lists"

log_message "Stopping the tyk-pump service (from Tyk deployment), preventing it from consuming the analytics records which we want to be processed by the Pump from this deployment."
eval $(generate_docker_compose_command) stop tyk-pump 2> /dev/null
if [ "$?" != 0 ]; then
  echo "Error stopping Pump container tyk-pump"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Verifying that tyk-pump process has stopped"
service_process=$(eval $(generate_docker_compose_command) top tyk-pump)
if [ "$service_process" != "" ]; then
  log_message "  ERROR: tyk-pump process has not stopped. Exiting."
  exit 1
fi
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Analytics - Datadog
  ▽ Datadog
                    URL : $datadog_dashboard"
