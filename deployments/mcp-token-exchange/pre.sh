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
#
# The versions in .env are not changed here: the user's choice is respected, and a
# warning is shown if it is below the minimum.
minimum_tyk_version="v5.14.0"

# Returns 0 if version $1 is at least version $2, 1 if it is lower, and 2 if $1 can't
# be parsed (e.g. a branch or commit tag). Pre-release suffixes are ignored, so
# v5.14.0-rc6 is treated as meeting a v5.14.0 minimum.
version_meets_minimum () {
  local actual="${1#v}"
  local minimum="${2#v}"
  actual="${actual%%-*}"
  minimum="${minimum%%-*}"

  if [[ ! "$actual" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    return 2
  fi

  local actual_parts minimum_parts
  IFS='.' read -r -a actual_parts <<< "$actual"
  IFS='.' read -r -a minimum_parts <<< "$minimum"
  for i in 0 1 2; do
    local a="${actual_parts[$i]:-0}"
    local m="${minimum_parts[$i]:-0}"
    if (( 10#$a > 10#$m )); then return 0; fi
    if (( 10#$a < 10#$m )); then return 1; fi
  done
  return 0
}

# Resolves the version Docker Compose will use: the .env value if set, otherwise the
# default declared in the base tyk deployment's compose file.
resolve_tyk_version () {
  local variable_name="$1"
  local version=$(grep -E "^$variable_name=" .env | tail -n 1 | cut -d '=' -f2- | tr -d "\"' ")
  if [ -z "$version" ]; then
    version=$(grep -oE "\\\$\{$variable_name:-[^}]+\}" deployments/tyk/docker-compose.yml | head -n 1 | sed -E 's/.*:-([^}]+)\}/\1/')
  fi
  echo "$version"
}

for variable_name in DASHBOARD_VERSION GATEWAY_VERSION; do
  version=$(resolve_tyk_version "$variable_name")
  version_meets_minimum "$version" "$minimum_tyk_version"
  case $? in
    0)
      log_message "mcp-token-exchange: $variable_name $version meets minimum $minimum_tyk_version"
      ;;
    1)
      echo "WARNING: mcp-token-exchange requires Tyk $minimum_tyk_version or later, but $variable_name is $version."
      echo "         Token exchange will not work. Set $variable_name to $minimum_tyk_version or later in .env and re-run up.sh."
      log_message "WARNING: mcp-token-exchange: $variable_name $version is below minimum $minimum_tyk_version"
      ;;
    *)
      echo "WARNING: mcp-token-exchange could not verify $variable_name '$version' is $minimum_tyk_version or later. Continuing anyway."
      log_message "WARNING: mcp-token-exchange: unable to parse $variable_name '$version'"
      ;;
  esac
done

echo "mcp-token-exchange: environment checked (minimum Tyk $minimum_tyk_version)"
