#!/bin/bash

source scripts/common.sh
deployment="Analytics - Datadog"
log_start_deployment
bootstrap_progress

datadog_dashboard="https://app.datadoghq.com/dashboard/lists"


log_message "Stopping the pump instance deployed by the base deployment"
# so it is replaced by the instance from this deployment
docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) stop tyk-pump 2> /dev/null
log_ok
bootstrap_progress

echo -e "\033[2K
▼ Analytics - Datadog
  ▽ Datadog
                    URL : $datadog_dashboard"
