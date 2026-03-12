#!/usr/bin/env bash
# Creates a keyless API and drives success + error traffic with X-Tenant-ID
# and X-Customer-ID headers to populate:
#   tyk_requests_by_tenant_total, tyk_latency_by_tenant_seconds,
#   tyk_requests_by_customer_total
#
# Usage: bash scripts/tenant-traffic-gen.sh
#
# Prerequisites: tyk-demo stack running (./up.sh tyk)
# After running: wait ~10s then check Grafana panels 131–134
# Re-runnable: cleans up stale APIs on the same listen path before creating a new one
set -euo pipefail

DASHBOARD_URL="http://localhost:3000"
GATEWAY_URL="http://localhost:8080"
GATEWAY_SECRET="28d220fd77974a4facfb07dc1e49c2aa"
LISTEN_PATH="/tenant-demo"

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

echo ">>> Step 2: Delete any stale Tenant Demo APIs"
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

echo ">>> Step 3: Create keyless API"
API_DEF=$(cat <<EOF
{
  "api_definition": {
    "name": "Tenant Demo API",
    "slug": "tenant-demo",
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
echo "    created API ID: $API_ID (doc: $DOC_ID)"

echo ">>> Step 4: Hot reload gateway"
curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
  -H "x-tyk-authorization: $GATEWAY_SECRET" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('    status:', d.get('status','?'))"
echo "    waiting 3s for API to become available..."
sleep 3

TENANTS=("tenant-alpha" "tenant-beta" "tenant-gamma")
CUSTOMERS=("cust-001" "cust-002" "cust-003")

echo ">>> Step 5: Generate success traffic (60 requests, ~0.5s apart)"
for i in $(seq 0 59); do
  TENANT="${TENANTS[$((i % 3))]}"
  CUSTOMER="${CUSTOMERS[$((i % 3))]}"
  curl -s \
    -H "X-Tenant-ID: $TENANT" \
    -H "X-Customer-ID: $CUSTOMER" \
    "$GATEWAY_URL$LISTEN_PATH/get" -o /dev/null && printf "."
  sleep 0.5
done
echo " done"

echo ">>> Step 6: Generate error traffic (15 requests → HTTP 500, ~1s apart)"
for i in $(seq 0 14); do
  TENANT="${TENANTS[$((i % 3))]}"
  CUSTOMER="${CUSTOMERS[$((i % 3))]}"
  curl -s \
    -H "X-Tenant-ID: $TENANT" \
    -H "X-Customer-ID: $CUSTOMER" \
    "$GATEWAY_URL$LISTEN_PATH/status/500" -o /dev/null && printf "e"
  sleep 1
done
echo " done"

echo ""
echo "Tenant traffic generated successfully!"
echo "  API ID   : $API_ID"
echo "  Tenants  : ${TENANTS[*]}"
echo "  Customers: ${CUSTOMERS[*]}"
echo "  Requests : 60 success + 15 errors (~45s total)"
echo ""
echo "Wait ~10s for the OTLP export interval, then check Grafana:"
echo "  Panel 131 — Per-Tenant Request Rate"
echo "  Panel 132 — Tenant Error Rate"
echo "  Panel 133 — Per-Tenant P95 Latency"
echo "  Panel 134 — Tenant SLO Dashboard"
echo ""
echo "Verify in Prometheus:"
echo "  tyk_requests_by_tenant_total{service_name=\"tyk-gateway\"}"
echo "  tyk_requests_by_customer_total{service_name=\"tyk-gateway\"}"
