#!/bin/bash

source scripts/common.sh

deployment="Backstage"
log_start_deployment

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>> logs/bootstrap.log)

log_message "Adding API event webhook to default organisation"
updated_org_data=$(jq '.event_options += { "api_event": { "webhook": "http://backstage:7007/api/catalog/tyk/development/sync" } }' < deployments/tyk/data/tyk-dashboard/1/organisation.json)
api_response=$(curl $dashboard_base_url/admin/organisations/5e9d9544a1dcd60001d0ed20 --request PUT -s \
    -H "admin-auth: $dashboard_admin_api_credentials" \
    -d "$updated_org_data" 2>> logs/bootstrap.log)
log_json_result "$api_response"

log_message "Writing Tyk Dashboard API access token to .env file"
set_docker_environment_value "TYK_DASHBOARD_API_ACCESS_CREDENTIALS" "$dashboard_api_key"
log_ok

log_message "Restarting Backstage container to use new access token env var value"
# The backstage container will show error messages prior to this restart, as it will have been using an invalid token
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate backstage 2> /dev/null
log_ok

log_end_deployment

echo -e "\033[2K
▼ Portal - Backstage
  ▽ Backstage
          Dashboard URL : http://localhost:3003
   Entity Provider Sync : http://localhost:7007/api/catalog/tyk/development/sync"
