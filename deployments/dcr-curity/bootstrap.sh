#!/bin/bash

source scripts/common.sh
deployment="dcr-curity"
log_start_deployment
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

curity_admin_url="https://curity:6749/admin"
curity_runtime_url="https://curity:8443"
curity_health_url="http://curity:4465"

log_message "Waiting for Curity to respond ok"
wait_for_response "$curity_health_url" "200"

log_message "Creating DCR API"
create_api "deployments/dcr-curity/data/tyk-dashboard/curity-dcr-api.json" "$dashboard_user_api_key"
bootstrap_progress


# Enterprise Portal setup
portal_base_url="http://tyk-portal.localhost:3100"
log_message "Waiting for Enterprise Portal to be ready"
wait_for_response "$portal_base_url/ready" "200" "" "10"

if [ $? -eq 0 ]; then
    # Get Portal Admin API token
    portal_admin_api_token=$(get_context_data "1" "enterprise-portal-admin" "1" "api-key")
    
    if [ -n "$portal_admin_api_token" ]; then

        # Configure OAuth2.0 Provider
        log_message "Configuring OAuth2.0 Provider for Curity DCR"
        oauth_provider_data='{
            "Name": "Curity DCR Provider",
            "Type": "Other",
            "WellKnownURL": "https://curity:8443/oauth/v2/oauth-anonymous/.well-known/openid-configuration",
            "SSLInsecureSkipVerify": true
        }'
            
        oauth_provider_response=$(curl --location "$portal_base_url/portal-api/oauth-providers" -s \
            --header 'Content-Type: application/json' \
            --header "Authorization: $portal_admin_api_token" \
            --data "$oauth_provider_data")
        log_message "OAuth2 Provider Response: $oauth_provider_response"
        oauth_provider_id=$(echo $oauth_provider_response | jq -r '.ID')
        log_message "Created OAuth2 Provider with ID: $oauth_provider_id"
        bootstrap_progress
            
        # Create client type for the OAuth provider
        log_message "Creating Client Type for OAuth Provider"
        client_type_data='{
            "Name": "Confidential Client",
            "Description": "Client type for confidential applications",
            "GrantType": ["client_credentials"],
            "ResponseTypes": ["token"],
            "TokenEndpointAuthMethod": ["client_secret_basic"]
        }'
            
        client_type_response=$(curl --location "$portal_base_url/portal-api/oauth-providers/$oauth_provider_id/client-types" -s \
            --header 'Content-Type: application/json' \
            --header "Authorization: $portal_admin_api_token" \
            --data "$client_type_data")
        log_message "Client Type Response: $client_type_response"
        client_type_id=$(echo $client_type_response | jq -r '.ID')
        log_message "Created Client Type with ID: $client_type_id"
        bootstrap_progress

         # Configure API Product
        log_message "Configuring API Product Curity DCR API"
        api_product_data_path="deployments/dcr-curity/data/tyk-portal/curity-dcr-product.json"
        if [[ ! -f "$api_product_data_path" ]]; then
            log_message "ERROR: File not found: $api_product_data_path"    
        fi
        api_product_data=$(cat "$api_product_data_path")
        api_product_response=$(curl --location "$portal_base_url/portal-api/products" -s \
            --header 'Content-Type: application/json' \
            --header "Authorization: $portal_admin_api_token" \
            --data "$api_product_data")
        log_message "API Product Response: $api_product_response"
        api_product_id=$(echo $api_product_response | jq -r '.ID')
        log_message "Created API Product with ID: $api_product_id"
        bootstrap_progress

         # Configure API Plan
        log_message "Configuring API Plan Curity DCR"
        api_plan_data_path="deployments/dcr-curity/data/tyk-portal/curity-dcr-plan.json"
        if [[ ! -f "$api_plan_data_path" ]]; then
            log_message "ERROR: File not found: $api_plan_data_path"    
        fi
        api_plan_data=$(cat "$api_plan_data_path")
        api_plan_response=$(curl --location "$portal_base_url/portal-api/plans" -s \
            --header 'Content-Type: application/json' \
            --header "Authorization: $portal_admin_api_token" \
            --data "$api_plan_data")
        log_message "API Plan Response: $api_plan_response"
        api_plan_id=$(echo $api_plan_response | jq -r '.ID')
        log_message "Created API Plan with ID: $api_plan_id"
        bootstrap_progress
       
    else
        log_message "ERROR: Could not get Portal Admin API token"
        exit 1
    fi
else
    log_message "ERROR: Enterprise Portal is not available. Please ensure portal deployment is running."
    exit 1
fi


log_message "Hot reloading Gateways"
hot_reload "$gateway_base_url" "$gateway_api_credentials" "group"
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Dynamic Client Registration
  ▽ Curity Admin
            Browser URL : $curity_admin_url
      Username/Password : admin/Password1"
