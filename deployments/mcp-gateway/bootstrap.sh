#!/bin/bash

# Bootstrap for the MCP Gateway demo deployment.
#
# This deployment intentionally does NOT create any MCP proxies, policies, or
# keys in the Dashboard — the demo script walks through building all of those
# live in front of the customer. Bootstrapping them would defeat the point.
#
# We do create a single REST proxy (`mock-mcp`) that fronts the mock MCP
# server. This gives the presenter a known upstream to point the wizard at
# without leaking any of the MCP-specific demo flow.
#
# The supporting services (mock MCP server, MCP Inspector) are brought up by
# up.sh before this script runs.

source scripts/common.sh

deployment="MCP Gateway"
log_start_deployment
bootstrap_progress

log_message "Waiting for services to be ready"
wait_for_liveness
bootstrap_progress

log_message "Waiting for Mock MCP Server health"
for i in {1..30}; do
    if curl -sf http://localhost:7878/health >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
log_ok
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

# MCP Proxies use a separate endpoint (/api/mcps) from regular OAS APIs
# (/api/apis/oas), so we can't use the shared create_api helper here.
log_message "Creating mock-mcp MCP Proxy"
mock_mcp_api_path="deployments/mcp-gateway/data/tyk-dashboard/apis/mock-mcp.json"
mock_mcp_response=$(curl -s "$dashboard_base_url/api/mcps/" \
  -H "Authorization: $dashboard_user_api_key" \
  -H "Content-Type: application/json" \
  -d @"$mock_mcp_api_path" 2>> logs/bootstrap.log)
log_json_result "$mock_mcp_response"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ MCP Gateway
  ▽ Mock MCP Server
                    URL : http://localhost:7878
           Health check : http://localhost:7878/health
        From the Gateway : http://mcp-mock-server:7878/mcp
  ▽ MCP Inspector
                    URL : http://localhost:6274
              Transport : Streamable HTTP
             Server URL : http://tyk-gateway:8080/<your-proxy>/mcp"