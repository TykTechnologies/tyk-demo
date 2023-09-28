#!/bin/bash

source scripts/common.sh
deployment="Subscriptions"
log_start_deployment
bootstrap_progress

chat_base_url="http://localhost:${SUBSCRIPTIONS_CHAT_APP_PORT:-8093}"

log_message "Waiting for chat application to respond ok"
wait_for_response "$chat_base_url" "200"

dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

# Create APIs
create_api "deployments/subscriptions/data/apis-chatapp.json" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Subscriptions
  ▽ Chat application
         Playground URL : $chat_base_url
       GraphQL Endpoint : $chat_base_url/query"
