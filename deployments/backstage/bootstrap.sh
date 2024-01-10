#!/bin/bash

source scripts/common.sh
deployment="Backstage"

log_start_deployment
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>> logs/bootstrap.log)

# this assumes that the backstage backend is available on the host machine on port 7007, and that it has the tyk entitiy provider installed
log_message "Adding API event webhook to default organisation"
updated_org_data=$(jq '.event_options += { "api_event": { "webhook": "http://host.docker.internal:7007/tyk/sync", "email": "", "redis": false } }' < deployments/tyk/data/tyk-dashboard/1/organisation.json)
api_response=$(curl $dashboard_base_url/admin/organisations/5e9d9544a1dcd60001d0ed20 --request PUT -s \
    -H "admin-auth: $dashboard_admin_api_credentials" \
    -d "$updated_org_data" 2>> logs/bootstrap.log)
log_json_result "$api_response"

bootstrap_progress
log_end_deployment

# blank output to overwrite "bootstrapping..." message
echo -e "\033[2K "
