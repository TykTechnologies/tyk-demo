#!/bin/bash

source scripts/common.sh
deployment="oauth-introspection"
log_start_deployment
bootstrap_progress

# Configuration
keycloak_base_url="http://keycloak.localhost:8180"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

log_message "Waiting for Keycloak to be ready"
wait_for_response "$keycloak_base_url/health/ready" "200"

log_message "Getting Keycloak admin access token"
admin_token_response=$(curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  "$keycloak_base_url/realms/master/protocol/openid-connect/token")

access_token=$(echo $admin_token_response | jq -r '.access_token')
log_message "Admin access token obtained"
log_ok
bootstrap_progress

log_message "Creating 'tyk' realm in Keycloak"
log_http_result "$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $access_token" \
  -d '{
    "realm": "tyk",
    "enabled": true,
    "displayName": "Tyk Realm",
    "accessTokenLifespan": 300
  }' \
  -o /dev/null \
  -w "%{http_code}" \
  "$keycloak_base_url/admin/realms")"
bootstrap_progress

log_message "Creating introspection client for Tyk Gateway"
log_http_result "$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $access_token" \
  -d '{
    "clientId": "tyk-introspection-client",
    "name": "Tyk Introspection Client",
    "enabled": true,
    "secret": "tyk-introspection-secret",
    "serviceAccountsEnabled": true,
    "standardFlowEnabled": false,
    "directAccessGrantsEnabled": false,
    "publicClient": false
  }' \
  -o /dev/null \
  -w "%{http_code}" \
  "$keycloak_base_url/admin/realms/tyk/clients")"
bootstrap_progress

log_message "Creating test client for generating tokens"
log_http_result "$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $access_token" \
  -d '{
    "clientId": "test-client",
    "name": "Test Client",
    "enabled": true,
    "secret": "test-client-secret",
    "directAccessGrantsEnabled": true,
    "serviceAccountsEnabled": true,
    "standardFlowEnabled": true,
    "publicClient": false
  }' \
  -o /dev/null \
  -w "%{http_code}" \
  "$keycloak_base_url/admin/realms/tyk/clients")"
bootstrap_progress

log_message "Creating test user"
log_http_result "$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $access_token" \
  -d '{
    "username": "testuser",
    "firstName": "Test",
    "lastName": "User",
    "email": "testuser@example.com",
    "enabled": true,
    "credentials": [{
      "type": "password",
      "value": "password",
      "temporary": false
    }]
  }' \
  -o /dev/null \
  -w "%{http_code}" \
  "$keycloak_base_url/admin/realms/tyk/users")"
bootstrap_progress

if [ -f .bootstrap/skip_plugin_build ]; then
  log_message "Skipping Go plugin build - skip_plugin_build flag is set"
else
  build_go_plugin "deployments/oauth-introspection/volumes/tyk-gateway/plugins/go/introspection/introspection.so"
  bootstrap_progress
fi

log_message "Creating introspection API"
create_api "deployments/oauth-introspection/data/tyk-dashboard/apis/introspection-api.json" "$dashboard_user_api_key"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ OAuth Introspection
  ▽ Keycloak Resources
                  Realm : tyk
    ▾ Introspection Client
              Client ID : tyk-introspection-client
          Client Secret : tyk-introspection-secret
    ▾ Test Client
              Client ID : test-client
          Client Secret : test-client-secret
    ▾ Test User
               Username : testuser
               Password : password"
