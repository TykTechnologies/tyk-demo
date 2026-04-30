#!/bin/bash

# Bootstrap for the MCP Gateway demo deployment.
#
# This deployment intentionally does NOT create any MCP proxies, policies, or
# keys in the Dashboard — the demo script walks through building all of those
# live in front of the customer. Bootstrapping them would defeat the point.
#
# The supporting services (mock MCP server, MCP Inspector) are brought up by
# up.sh before this script runs. All we do here is wait for the mock server
# to be healthy and surface URLs to the presenter.

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