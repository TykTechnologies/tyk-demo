#!/bin/bash

source scripts/common.sh
deployment="portal"

log_start_deployment
bootstrap_progress

dashboard_user_api_credentials=$(cat .context-data/1-dashboard-user-1-api-key)

#log_message $dashboard_user_api_credentials
#bash /opt/portal/dev-portal

set_docker_environment_value "TYK_DASHBOARD_API_ACCESS_CREDENTIALS" $dashboard_user_api_credentials
log_message "Restarting tyk-portal."

$(generate_docker_compose_command) stop tyk-portal 2> /dev/null
$(generate_docker_compose_command) rm -f tyk-portal 2> /dev/null
$(generate_docker_compose_command) up -d tyk-portal 2> /dev/null

log_ok
