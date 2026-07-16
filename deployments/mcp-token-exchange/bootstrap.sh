#!/bin/bash

source scripts/common.sh
deployment="mcp-token-exchange"
log_start_deployment
bootstrap_progress

data_dir="deployments/mcp-token-exchange/data/tyk-dashboard"
dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")
gateway_base_url="http://tyk-gateway.localhost:8080"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
keycloak_base_url="http://acme-keycloak:8280"
keycloak_issuer="$keycloak_base_url/realms/acme"

log_message "Waiting for Dashboard API to be ready"
wait_for_response "$dashboard_base_url/admin/organisations" "200" "admin-auth: $dashboard_admin_api_credentials"
bootstrap_progress

log_message "Waiting for Keycloak to import the acme realm"
wait_for_response "$keycloak_issuer/.well-known/openid-configuration" "200"
log_ok
bootstrap_progress

# The APIs use JWT auth, which returns "403 Access disallowed" unless the JWT
# scheme has a default policy, and the policy needs the API ids in its access
# rights. So: create the APIs (empty defaultPolicies), create the policy
# referencing them, then update the APIs to reference the policy.

log_message "Creating Acme API (OAS)"
api_response=$(curl "$dashboard_base_url/api/apis/oas" -s \
  -H "Authorization: $dashboard_user_api_key" \
  -H "Content-Type: application/json" \
  --data-binary @"$data_dir/acme-api.oas.json" 2>> logs/bootstrap.log)
log_json_result "$api_response"
bootstrap_progress

log_message "Creating Acme MCP Proxy API"
api_response_status_code=$(curl "$dashboard_base_url/api/mcps" -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: $dashboard_user_api_key" \
  -H "Content-Type: application/json" \
  --data-binary @"$data_dir/acme-mcp-proxy.oas.json" 2>> logs/bootstrap.log)
if [ "$api_response_status_code" != "200" ] && [ "$api_response_status_code" != "201" ]; then
  log_message "ERROR: MCP API creation returned HTTP $api_response_status_code"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Resolving API ids"
acme_api_id=$(curl -s "$dashboard_base_url/api/apis?p=-1" -H "Authorization: $dashboard_user_api_key" | \
  jq -r '.apis[] | select(.api_definition.name == "acme-api") | .api_definition.api_id' | head -n1)
acme_mcp_id=$(curl -s "$dashboard_base_url/api/mcps" -H "Authorization: $dashboard_user_api_key" | \
  jq -r '.mcps[]? | select(.["x-tyk-api-gateway"].info.name == "acme-mcp-proxy") | .["x-tyk-api-gateway"].info.id' | head -n1)
if [ -z "$acme_api_id" ] || [ -z "$acme_mcp_id" ]; then
  log_message "ERROR: Could not resolve API ids (acme-api: '$acme_api_id', acme-mcp-proxy: '$acme_mcp_id')"
  exit 1
fi
log_message "  acme-api: $acme_api_id"
log_message "  acme-mcp-proxy: $acme_mcp_id"
log_ok
bootstrap_progress

log_message "Creating Acme demo policy"
access_rights=$(jq -n --arg oas "$acme_api_id" --arg mcp "$acme_mcp_id" \
  '{($oas): {api_id: $oas, api_name: "acme-api", versions: ["Default"], allowed_urls: []},
    ($mcp): {api_id: $mcp, api_name: "acme-mcp-proxy", versions: ["Default"], allowed_urls: []}}')
policy_body=$(jq --argjson ar "$access_rights" 'del(.apis) + {access_rights: $ar}' "$data_dir/policy.json")
policy_response=$(curl "$dashboard_base_url/api/portal/policies" -s \
  -H "Authorization: $dashboard_user_api_key" \
  -H "Content-Type: application/json" \
  -d "$policy_body" 2>> logs/bootstrap.log)
policy_id=$(jq -r '.Message' <<< "$policy_response")
log_message "  ID: $policy_id"
log_json_result "$policy_response"
bootstrap_progress

log_message "Binding policy to JWT auth (defaultPolicies)"
inject_default_policy() {
  jq --arg p "$1" '.["x-tyk-api-gateway"].server.authentication.securitySchemes |=
    with_entries(if .value.jwksURIs then .value.defaultPolicies = [$p] else . end)' "$2"
}
api_response=$(inject_default_policy "$policy_id" "$data_dir/acme-api.oas.json" | \
  curl "$dashboard_base_url/api/apis/oas/$acme_api_id" -s -X PUT \
    -H "Authorization: $dashboard_user_api_key" \
    -H "Content-Type: application/json" \
    --data-binary @- 2>> logs/bootstrap.log)
log_json_result "$api_response"
api_response_status_code=$(inject_default_policy "$policy_id" "$data_dir/acme-mcp-proxy.oas.json" | \
  curl "$dashboard_base_url/api/mcps/$acme_mcp_id" -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Authorization: $dashboard_user_api_key" \
    -H "Content-Type: application/json" \
    --data-binary @- 2>> logs/bootstrap.log)
if [ "$api_response_status_code" != "200" ]; then
  log_message "ERROR: MCP API policy binding returned HTTP $api_response_status_code"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Hot reloading Gateways"
hot_reload "$gateway_base_url" "$gateway_api_credentials" "group"
log_ok
bootstrap_progress

log_message "Waiting for Copilot Chat to be ready"
wait_for_response "http://localhost:8095/" "200"
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ MCP Token Exchange (Acme Support Copilot)
  ▽ Copilot Chat
                    URL : http://localhost:8095
                  Users : alice / Acme-Demo-2026! (read-only)
                          bob / Acme-Demo-2026! (read + refund)
                 Guides : http://localhost:8095/guide (plain English)
                          http://localhost:8095/setup (technical)
  ▽ MCP Proxy
           MCP Endpoint : http://tyk-gateway.localhost:8080/acme-mcp/mcp
  ▽ Keycloak
            Browser URL : http://acme-keycloak:8280
      Username/Password : admin/admin
  ▽ Observability (requires the opentelemetry-demo deployment)
                Grafana : http://localhost:8085/grafana/
    MCP Usage Dashboard : http://localhost:8085/grafana/d/acme-mcp-usage
    MCP Metrics (gw-native) : http://localhost:8085/grafana/d/tyk-mcp-metrics
          SLO Dashboard : http://localhost:8085/grafana/d/YjXeVVZ4k"
