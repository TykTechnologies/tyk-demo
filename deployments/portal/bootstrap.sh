#!/bin/bash

source scripts/common.sh
deployment="portal"

log_start_deployment
bootstrap_progress

dashboard_user_api_credentials=$(cat .context-data/1-dashboard-user-1-api-key)
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)


set_docker_environment_value "TYK_DASHBOARD_API_ACCESS_CREDENTIALS" $dashboard_user_api_credentials
log_message "Restarting tyk-portal."

$(generate_docker_compose_command) stop tyk-portal 2> /dev/null
$(generate_docker_compose_command) rm -f tyk-portal 2> /dev/null
$(generate_docker_compose_command) up -d tyk-portal 2> /dev/null

log_ok

# Create Plans and Policies for NEW Developer Portal
log_message "Creating Enterprise Portal Plans"
for file in deployments/portal/volumes/tyk-portal/plans/*; do 
  if [[ -f $file ]]; then
  	policy=`cat $file`
    curl http://tyk-dashboard.localhost:3000/api/portal/policies -s \
      -o /dev/null \
      -H "authorization: $dashboard_user_api_credentials" \
      -d "$policy"
  fi
done

log_message "Creating Enterprise Portal Products"
for file in deployments/portal/volumes/tyk-portal/products/*; do 
  if [[ -f $file ]]; then
  	policy=`cat $file`
    curl http://tyk-dashboard.localhost:3000/api/portal/policies -s \
      -o /dev/null \
      -H "authorization: $dashboard_user_api_credentials" \
      -d "$policy"
  fi
done

log_ok