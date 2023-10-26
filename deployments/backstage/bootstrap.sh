#!/bin/bash

source scripts/common.sh
deployment="Backstage"

log_start_deployment
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

log_message "Updating Dashboard API definition to use current Dashboard API key"
updated_api_data=$(jq --compact-output --raw-output --arg dashboard_api_key "$dashboard_api_key" '.api_definition.version_data.versions.Default.global_headers.Authorization = $dashboard_api_key' deployments/backstage/data/tyk-dashboard/api-653a7e6942033d00015b9059.json)
log_json_result "$(curl $dashboard_base_url/api/apis -s \
    -H "Authorization: $dashboard_api_key" \
    -d "$updated_api_data")"

bootstrap_progress

log_end_deployment