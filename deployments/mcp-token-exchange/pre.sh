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

# Token exchange ships in 5.14.0; the gateway-native exchange/MCP observability
# (OTel exchange span, tyk_mcp_call_* and tyk_oauth2_exchange_* metrics) follows
# in 5.15.0. The OpenTelemetry variables are handled by up.sh, keyed on the
# deployment name.
tyk_version="v5.14.0-rc6"
set_docker_environment_value "DASHBOARD_VERSION" "$tyk_version"
set_docker_environment_value "GATEWAY_VERSION" "$tyk_version"
set_docker_environment_value "GATEWAY2_VERSION" "$tyk_version"

echo "mcp-token-exchange: environment set (Tyk $tyk_version)"
