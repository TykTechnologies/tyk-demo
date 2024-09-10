#!/bin/bash

source scripts/common.sh

deployment="Backstage"
log_start_deployment

log_message "Writing Tyk Dashboard API access token to .env file"
set_docker_environment_value "TYK_DASHBOARD_API_ACCESS_CREDENTIALS" $(cat .context-data/1-dashboard-user-1-api-key)
log_ok

log_message "Restarting Backstage container to use new access token env var value"
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate backstage 2> /dev/null
log_ok

log_end_deployment

echo -e "\033[2K
▼ Portal - Backstage
  ▽ Backstage
          Dashboard URL : http://localhost:3003"
