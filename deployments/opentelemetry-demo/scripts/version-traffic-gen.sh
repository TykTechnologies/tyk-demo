#!/usr/bin/env bash
# Creates a single keyless API proxying to httpbin and drives traffic to populate:
#   tyk_requests_by_backend_version_total  → panel 144 "Backend Version Distribution Over Time"
#   tyk_requests_by_content_type_total     → panel 145 "Response Content-Type Mix"
#
# Uses httpbin's /response-headers endpoint to control both response headers per version:
#   v1  X-Backend-Version: v1  Content-Type: application/json
#   v2  X-Backend-Version: v2  Content-Type: text/html
#   v3  X-Backend-Version: v3  Content-Type: application/gzip
#
# Usage: bash deployments/opentelemetry-demo/scripts/version-traffic-gen.sh
#
# Prerequisites: tyk-demo stack running (./up.sh tyk)
# After running: wait ~10s then check Grafana panels 144–145
# Re-runnable: cleans up stale API on the same listen path before creating a new one
set -euo pipefail

DASHBOARD_URL="http://localhost:3000"
GATEWAY_URL="http://localhost:8080"
GATEWAY_SECRET="28d220fd77974a4facfb07dc1e49c2aa"
LISTEN_PATH="/version-demo"

echo ">>> Step 1: Get Dashboard user API key and org_id"
BOOTSTRAP_LOG="logs/bootstrap.log"
if [[ ! -f "$BOOTSTRAP_LOG" ]]; then
  echo "ERROR: $BOOTSTRAP_LOG not found. Run ./up.sh tyk first."
  exit 1
fi
USER_KEY=$(grep "API Key:" "$BOOTSTRAP_LOG" | head -1 | awk '{print $NF}')
if [[ -z "$USER_KEY" ]]; then
  echo "ERROR: Could not extract API key from $BOOTSTRAP_LOG"
  exit 1
fi
USER_RESP=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/users")
ORG_ID=$(echo "$USER_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['users'][0]['org_id'])")
echo "    user key: $USER_KEY  org: $ORG_ID"

echo ">>> Step 2: Delete any stale Version Demo APIs"
EXISTING=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis?p=-1" | \
  python3 -c "
import sys,json
apis=json.load(sys.stdin)['apis']
ids=[a['api_definition']['api_id'] for a in apis if a['api_definition'].get('proxy',{}).get('listen_path','') == '$LISTEN_PATH/']
print(' '.join(ids))
")
for OLD_ID in $EXISTING; do
  curl -sf -X DELETE "$DASHBOARD_URL/api/apis/$OLD_ID" -H "Authorization: $USER_KEY" > /dev/null
  echo "    deleted stale API: $OLD_ID"
done

echo ">>> Step 3: Create Version Demo API (proxy to httpbin)"
API_DEF=$(cat <<EOF
{
  "api_definition": {
    "name": "Version Demo API #otel-demo",
    "slug": "version-demo",
    "api_id": "",
    "org_id": "$ORG_ID",
    "use_keyless": true,
    "use_oauth2": false,
    "proxy": {
      "listen_path": "$LISTEN_PATH/",
      "target_url": "http://httpbin/",
      "strip_listen_path": true
    },
    "active": true,
    "enable_detailed_recording": true,
    "version_data": {
      "not_versioned": true,
      "default_version": "Default",
      "versions": {
        "Default": { "name": "Default", "use_extended_paths": true, "extended_paths": {} }
      }
    }
  },
  "hook_references": [], "is_site": false, "sort_by": 0,
  "user_group_owners": [], "user_owners": []
}
EOF
)

CREATE_RESP=$(curl -sf -X POST "$DASHBOARD_URL/api/apis" \
  -H "Authorization: $USER_KEY" \
  -H "Content-Type: application/json" \
  -d "$API_DEF")
DOC_ID=$(echo "$CREATE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['Meta'])")
API_ID=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis/$DOC_ID" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['api_definition']['api_id'])")
echo "    created API ID: $API_ID"

echo ">>> Step 4: Hot reload gateway"
curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
  -H "x-tyk-authorization: $GATEWAY_SECRET" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('    status:', d.get('status','?'))"
echo "    waiting 3s for API to become available..."
sleep 3

# httpbin /response-headers sets whatever headers are passed as query params.
# Combining X-Backend-Version and Content-Type in one call gives both metrics per version.
V1_PATH="response-headers?X-Backend-Version=v1&Content-Type=application/json"
V2_PATH="response-headers?X-Backend-Version=v2&Content-Type=text/html"
V3_PATH="response-headers?X-Backend-Version=v3&Content-Type=application/gzip"

V1_COUNT=0
V2_COUNT=0
V3_COUNT=0

echo ">>> Step 5: Generate interleaved traffic (90 requests, ratio v1:v2:v3 = 4:3:2)"
echo "    v1 → /response-headers?X-Backend-Version=v1&Content-Type=application/json"
echo "    v2 → /response-headers?X-Backend-Version=v2&Content-Type=text/html"
echo "    v3 → /response-headers?X-Backend-Version=v3&Content-Type=application/gzip"

for i in $(seq 0 89); do
  SLOT=$((i % 9))
  if [ "$SLOT" -lt 4 ]; then
    curl -s "$GATEWAY_URL$LISTEN_PATH/$V1_PATH" -o /dev/null && printf "1"
    V1_COUNT=$((V1_COUNT + 1))
  elif [ "$SLOT" -lt 7 ]; then
    curl -s "$GATEWAY_URL$LISTEN_PATH/$V2_PATH" -o /dev/null && printf "2"
    V2_COUNT=$((V2_COUNT + 1))
  else
    curl -s "$GATEWAY_URL$LISTEN_PATH/$V3_PATH" -o /dev/null && printf "3"
    V3_COUNT=$((V3_COUNT + 1))
  fi
  sleep 0.5
done
echo " done"

echo ""
echo "Version traffic generated successfully!"
echo "  v1 requests : $V1_COUNT (application/json)"
echo "  v2 requests : $V2_COUNT (text/html)"
echo "  v3 requests : $V3_COUNT (application/gzip)"
echo "  Total       : 90 requests (~45s)"
echo ""
echo "Wait ~10s for the OTLP export interval (configured: 5s), then check Grafana:"
echo "  Panel 144 — Backend Version Distribution Over Time (timeseries: v1/v2/v3 lines)"
echo "  Panel 145 — Response Content-Type Mix (piechart: json/html/gzip slices)"
echo ""
echo "Verify in Prometheus:"
echo "  tyk_requests_by_backend_version_total{service_name=\"tyk-gateway\"}"
echo "  tyk_requests_by_content_type_total{service_name=\"tyk-gateway\"}"
