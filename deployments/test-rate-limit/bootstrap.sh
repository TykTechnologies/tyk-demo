#!/bin/bash

source scripts/common.sh
deployment="Test Rate Limit"

log_start_deployment
bootstrap_progress

gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>> logs/bootstrap.log)
dashboard_user_api_credentials=$(cat .context-data/1-dashboard-user-1-api-key)

log_message "Importing APIs"
create_api deployments/test-rate-limit/data/tyk-dashboard/apis/load-balanced-api-auth.json $dashboard_admin_api_credentials $dashboard_user_api_credentials
bootstrap_progress

log_message "Importing Keys"
for file in deployments/test-rate-limit/data/tyk-gateway/keys/*; do
  if [[ -f $file ]]; then
    create_bearer_token "$file" "$gateway_api_credentials"
    bootstrap_progress
  fi
done

log_end_deployment
