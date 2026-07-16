#!/bin/bash

source scripts/common.sh

# Token exchange (RFC 8693) is an enterprise feature that ships in Tyk 5.14.
# It requires the EE gateway image, which up.sh selects automatically when the
# licence carries an enterprise scope.
if ! check_licence_requires_enterprise "DASHBOARD_LICENCE"; then
  echo "ERROR: The mcp-token-exchange deployment requires an enterprise-scoped licence."
  echo "On a standard gateway the token-exchange middleware is a no-op, so the demo cannot function."
  exit 1
fi

# Token exchange ships in 5.14.0. Gateway-native MCP metrics (tyk_mcp_requests_total
# etc.) are also available on 5.14 as configurable API metrics — the opentelemetry-demo
# deployment enables them via TYK_GW_OPENTELEMETRY_METRICS_APIMETRICS. Only the
# exchange-specific observability (exchange OTel span, tyk_oauth2_exchange_* metrics)
# is still unreleased (TT-17186). The OpenTelemetry variables are handled by up.sh,
# keyed on the deployment name.
tyk_version="v5.14.0"
set_docker_environment_value "DASHBOARD_VERSION" "$tyk_version"
set_docker_environment_value "GATEWAY_VERSION" "$tyk_version"
set_docker_environment_value "GATEWAY2_VERSION" "$tyk_version"

echo "mcp-token-exchange: environment set (Tyk $tyk_version)"
