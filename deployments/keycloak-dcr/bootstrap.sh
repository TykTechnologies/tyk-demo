#!/bin/bash

source scripts/common.sh
deployment="keycloak-dcr"
log_start_deployment
bootstrap_progress

log_message "Configuring Keycloak to disable SSL requirement"
docker exec tyk-demo-keycloak-1 /opt/keycloak/bin/kcadm.sh config credentials --server http://keycloak:8180 --realm master --user admin --password admin
docker exec tyk-demo-keycloak-1 /opt/keycloak/bin/kcadm.sh update realms/master -s sslRequired=NONE
log_ok
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")
gateway_base_url="http://tyk-gateway.localhost:8080"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
keycloak_base_url="http://keycloak:8180"

log_message "Waiting for Dashboard API to be ready"
wait_for_response "$dashboard_base_url/admin/organisations" "200" "admin-auth: $dashboard_admin_api_credentials"

log_message "Waiting for Keycloak to respond ok"
wait_for_response "$keycloak_base_url/health/ready" "200"


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
api_response="$(curl $keycloak_base_url/admin/realms/master/clients-initial-access -s \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $access_token" \
  -d '{"count": 5}')"
initial_access_token=$(echo $api_response | jq -r '.token')
log_message "initial_access_token: $initial_access_token"
log_ok
bootstrap_progress

log_message "Creating DCR API"
create_api "deployments/keycloak-dcr/data/tyk-dashboard/apis.json" "$dashboard_user_api_key"
bootstrap_progress

log_message "Creating Keycloak Reverse Proxy API"
create_api "deployments/keycloak-dcr/data/tyk-dashboard/keycloak-reverse-proxy.json" "$dashboard_user_api_key"
bootstrap_progress

log_message "Creating DCR Policy"
create_policy "deployments/keycloak-dcr/data/tyk-dashboard/policy.json" "$dashboard_user_api_key"
bootstrap_progress

# Enterprise Portal setup
portal_base_url="http://tyk-portal.localhost:3100"
log_message "Waiting for Enterprise Portal to be ready"
wait_for_response "$portal_base_url/ready" "200" "" "10"

if [ $? -eq 0 ]; then
    # Get Portal Admin API token
    portal_admin_api_token=$(get_context_data "1" "enterprise-portal-admin" "1" "api-key")
    
    if [ -n "$portal_admin_api_token" ]; then
        # Create Portal Plan
        log_message "Creating Enterprise Portal DCR Plan"
        plan_data=$(cat deployments/keycloak-dcr/data/tyk-portal/plan.json)
        plan_response=$(curl "$dashboard_base_url/api/portal/policies" -s \
            -H "authorization: $dashboard_user_api_key" \
            -d "$plan_data")
        log_message "Plan Response: $plan_response"
        plan_id=$(echo $plan_response | jq -r '._id')
        log_message "Created plan with ID: $plan_id"
        bootstrap_progress
        
        # Create Portal Product
        log_message "Creating Enterprise Portal DCR Product"
        product_data=$(cat deployments/keycloak-dcr/data/tyk-portal/product.json)
        product_response=$(curl "$dashboard_base_url/api/portal/policies" -s \
            -H "authorization: $dashboard_user_api_key" \
            -d "$product_data")
        log_message "Product Response: $product_response"
        product_id=$(echo $product_response | jq -r '._id')
        log_message "Created product with ID: $product_id"
        bootstrap_progress
        
        # Synchronize provider to get the latest products
        log_message "Synchronizing provider to refresh products"
        provider_id=$(curl --location "$portal_base_url/portal-api/providers" -s \
            --header "Authorization: $portal_admin_api_token" | jq -r '.[0].ID')
        
        curl --location --request PUT "$portal_base_url/portal-api/providers/$provider_id/synchronize" -s \
            --header "Authorization: $portal_admin_api_token" -o /dev/null
        bootstrap_progress
        
        # Wait for sync to complete
        sleep 2
        
        # Get the product ID in the portal
        log_message "Getting product from portal"
        products=$(curl --location "$portal_base_url/portal-api/products" -s \
            --header "Authorization: $portal_admin_api_token")
        portal_product_id=$(echo $products | jq -r '.[] | select(.Name == "Keycloak DCR API Product") | .ID')
        log_message "Portal product ID: $portal_product_id"
        
        if [ -n "$portal_product_id" ]; then
            # Configure OAuth2.0 Provider for DCR first
            log_message "Configuring OAuth2.0 Provider for Keycloak DCR"
            oauth_provider_data='{
                "Name": "Keycloak DCR Provider",
                "Type": "Keycloak",
                "WellKnownURL": "http://keycloak:8180/realms/master/.well-known/openid-configuration",
                "SSLInsecureSkipVerify": true,
                "RegistrationAccessToken": "'$initial_access_token'"
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
                "ResponseTypes": ["code"],
                "TokenEndpointAuthMethod": ["client_secret_post"],
                "ApplicationType": "confidential"
            }'
            
            client_type_response=$(curl --location "$portal_base_url/portal-api/oauth-providers/$oauth_provider_id/client-types" -s \
                --header 'Content-Type: application/json' \
                --header "Authorization: $portal_admin_api_token" \
                --data "$client_type_data")
            log_message "Client Type Response: $client_type_response"
            client_type_id=$(echo $client_type_response | jq -r '.ID')
            log_message "Created Client Type with ID: $client_type_id"
            bootstrap_progress
            
            # Update product to be visible in catalog, enable DCR, and link OAuth provider
            log_message "Publishing product to catalog and enabling DCR"
            product_details=$(curl --location "$portal_base_url/portal-api/products/$portal_product_id" -s \
                --header "Authorization: $portal_admin_api_token")
            
            # Update all settings in one go
            updated_product=$(echo $product_details | jq -r '.Catalogues = [1, 2]')
            updated_product=$(echo $updated_product | jq -r '.DCREnabled = true')
            
            curl --location --request PUT "$portal_base_url/portal-api/products/$portal_product_id" -s \
                --header 'Content-Type: application/json' \
                --header "Authorization: $portal_admin_api_token" \
                --data "$updated_product" -o /dev/null
            bootstrap_progress
            
            # Link client type to product
            log_message "Linking client type to product"
            curl --location --request POST "$portal_base_url/portal-api/products/$portal_product_id/client_types" -s \
                --header 'Content-Type: application/json' \
                --header "Authorization: $portal_admin_api_token" \
                --data "{\"ID\": $client_type_id}" -o /dev/null
            bootstrap_progress
            
            # Final sync to ensure everything is properly configured
            log_message "Final provider synchronization"
            curl --location --request PUT "$portal_base_url/portal-api/providers/$provider_id/synchronize" -s \
                --header "Authorization: $portal_admin_api_token" -o /dev/null
            log_ok
        else
            log_message "ERROR: Could not find product in portal"
            exit 1
        fi
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
  ▽ Keycloak
            Browser URL : $keycloak_base_url
      Username/Password : admin/admin"
