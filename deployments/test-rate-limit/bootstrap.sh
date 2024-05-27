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
for file in deployments/test-rate-limit/data/tyk-dashboard/apis/*; do
  if [[ -f $file ]]; then
    create_api $file $dashboard_admin_api_credentials $dashboard_user_api_credentials
    bootstrap_progress
  fi
done
log_ok

log_message "Importing Policies"
for file in deployments/test-rate-limit/data/tyk-dashboard/policies/*; do
  if [[ -f $file ]]; then
    create_policy $file $dashboard_admin_api_credentials $dashboard_user_api_credentials
    bootstrap_progress
  fi
done
log_ok

log_message "Restart Gateways to load latest certificates"
docker restart tyk-demo-tyk-gateway-3-1 tyk-demo-tyk-gateway-4-1 1>/dev/null 2>>logs/bootstrap.log
if [ "$?" != 0 ]; then
  echo "Error when restart Gateways to load latest certificates"
  exit 1
fi
log_ok

log_message "Restart nginx to reset load balancer"
docker restart tyk-demo-nginx-1 1>/dev/null 2>>logs/bootstrap.log
if [ "$?" != 0 ]; then
  echo "Error when restarting nginx to reset load balancer"
  exit 1
fi
log_ok

log_end_deployment
