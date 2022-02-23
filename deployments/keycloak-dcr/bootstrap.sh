#!/bin/bash

source scripts/common.sh
deployment="keycloak-dcr"
log_start_deployment
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")
gateway_base_url="http://tyk-gateway.localhost:8080"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
keycloak_base_url="http://keycloak:8180/auth"
keycloak_admin_url="http://keycloak:8180/auth/admin"

log_message "Waiting for Dashboard API to be ready"
wait_for_response "$dashboard_base_url/admin/organisations" "200" "admin-auth: $dashboard_admin_api_credentials"

log_message "Waiting for Keycloak to respond ok"
wait_for_response "$keycloak_base_url/" "200"


log_message "Obtaining keycloak user access token"
api_response="$(curl $keycloak_base_url/realms/master/protocol/openid-connect/token -s \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password")"
access_token=$(echo $api_response | jq -r '.access_token')
log_message "access_token: $access_token"
log_ok
bootstrap_progress


log_message "Creating a new initial access token"
api_response="$(curl $keycloak_admin_url/realms/master/clients-initial-access -s \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $access_token" \
  -d '{"count": 5}')"
initial_access_token=$(echo $api_response | jq -r '.token')
log_message "initial_access_token: $initial_access_token"
log_ok
bootstrap_progress


log_message "Importing DCR API"
log_json_result "$(curl $dashboard_base_url/admin/apis/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat deployments/keycloak-dcr/data/tyk-dashboard/apis.json)")"
bootstrap_progress


#log_message "Create DCR Policy"
#api_response="$(curl $dashboard_base_url/api/portal/policies -s \
#    -H "Authorization: $dashboard_user_api_key" \
#    -d "$(cat deployments/keycloak-dcr/data/tyk-dashboard/policy.json)")"
#log_json_result $api_response
#policy_id=$(echo $api_response | jq -r '.Message')
#bootstrap_progress


log_message "Importing DCR Policy"
import_request_payload=$(jq --slurpfile policy "deployments/keycloak-dcr/data/tyk-dashboard/policy.json" '.Data += $policy' deployments/tyk/data/tyk-dashboard/admin-api-policies-import-template.json)
log_json_result "$(curl $dashboard_base_url/admin/policies/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$import_request_payload")"
bootstrap_progress


#ACL is missing when importing Policy using Dash Admin API, so do a PUT using the normal Dashboard API
log_message "Updating DCR Policy"
policy_id=$(cat deployments/keycloak-dcr/data/tyk-dashboard/policy.json | jq -r .id)

log_json_result "$(curl -X 'PUT' $dashboard_base_url/api/portal/policies/$policy_id -s \
    -H "Authorization: $dashboard_user_api_key" \
    -d "$(cat deployments/keycloak-dcr/data/tyk-dashboard/policy.json)")"

bootstrap_progress

log_message "Importing DCR Portal Catalog"
catalogue_data_path="deployments/keycloak-dcr/data/tyk-dashboard/catalog.json"

# get the existing catalogue
existing_catalogue="$(curl $dashboard_base_url/api/portal/catalogue -s \
    -H "Authorization: $dashboard_user_api_key")"

# Inject initial access token into new catalogue entry
#new_catalogue=$(jq --arg pol_id "$policy_id" --arg dcr_token "$initial_access_token" '.policy_id = $pol_id | .config.dcr_options.access_token = $dcr_token' $catalogue_data_path)
new_catalogue=$(jq --arg dcr_token "$initial_access_token" '.config.dcr_options.access_token = $dcr_token' $catalogue_data_path)

# update the catalogue with the new catalogue entry
updated_catalogue=$(jq --argjson new_catalogue "[$new_catalogue]" '.apis += $new_catalogue' <<< "$existing_catalogue")
log_message "Updated catalogue: $updated_catalogue"

log_json_result "$(curl -X 'PUT' $dashboard_base_url/api/portal/catalogue -s \
    -H "Authorization: $dashboard_user_api_key" \
    -d "$updated_catalogue")"
bootstrap_progress


log_message "Hot reloading Gateways"
hot_reload "$gateway_base_url" "$gateway_api_credentials" "group"
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ IdP
  ▽ Keycloak
            Browser URL : $keycloak_admin_url
                  Login : admin/admin"
