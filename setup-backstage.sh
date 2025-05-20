#!/bin/bash

source scripts/common.sh

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")
dashboard_api_key2=$(get_context_data "tyk2" "dashboard-user" "1" "api-key")
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>> logs/bootstrap.log)

# Add API event webhook to default organisation
updated_org_data=$(jq '.event_options += { "api_event": { "webhook": "http://localhost:7007/api/catalog/tyk/development/sync" } }' < deployments/tyk/data/tyk-dashboard/1/organisation.json)
api_response=$(curl $dashboard_base_url/admin/organisations/5e9d9544a1dcd60001d0ed20 --request PUT -s \
    -H "admin-auth: $dashboard_admin_api_credentials" \
    -d "$updated_org_data" 2>> logs/bootstrap.log)

# Set the dashboard API key in the Backstage config
yq -i ".tyk.dashboards[0].token = \"${dashboard_api_key}\"" /Users/davidgarvey/git/backstage-tyk-entity-provider/app-config.local.yaml
yq -i ".tyk.dashboards[1].token = \"${dashboard_api_key2}\"" /Users/davidgarvey/git/backstage-tyk-entity-provider/app-config.local.yaml