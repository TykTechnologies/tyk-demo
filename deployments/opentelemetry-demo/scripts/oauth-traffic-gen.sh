#!/usr/bin/env bash
# Creates an OAuth 2.0 API, 3 OAuth clients, gets tokens, and drives
# success + error traffic to populate tyk_requests_by_oauth_total.
#
# Usage: bash scripts/oauth-traffic-gen.sh
#
# Prerequisites: tyk-demo stack running (./up.sh tyk)
# After running: wait ~10s then check Grafana panels 123 and 124
# Re-runnable: cleans up stale APIs on the same listen path before creating a new one
set -euo pipefail

DASHBOARD_URL="http://localhost:3000"
GATEWAY_URL="http://localhost:8080"
GATEWAY_SECRET="28d220fd77974a4facfb07dc1e49c2aa"
LISTEN_PATH="/oauth-demo"

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

echo ">>> Step 2: Delete any stale OAuth Demo APIs and policies"
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
# Delete stale policies named "OAuth Demo Policy"
STALE_POLICIES=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/portal/policies?p=-1" | \
  python3 -c "
import sys,json
d=json.load(sys.stdin)
ids=[p['_id'] for p in d.get('Data',[]) if p.get('name') == 'OAuth Demo Policy']
print(' '.join(ids))
")
for OLD_PID in $STALE_POLICIES; do
  curl -sf -X DELETE "$DASHBOARD_URL/api/portal/policies/$OLD_PID" -H "Authorization: $USER_KEY" > /dev/null
  echo "    deleted stale policy: $OLD_PID"
done

echo ">>> Step 3: Create OAuth 2.0 API"
API_DEF=$(cat <<EOF
{
  "api_definition": {
    "name": "OAuth Demo API",
    "slug": "oauth-demo",
    "api_id": "",
    "org_id": "$ORG_ID",
    "use_keyless": false,
    "use_oauth2": true,
    "oauth_meta": {
      "allowed_access_types": ["client_credentials"],
      "allowed_authorize_types": [],
      "auth_login_redirect": ""
    },
    "auth": { "auth_header_name": "Authorization" },
    "proxy": {
      "listen_path": "$LISTEN_PATH/",
      "target_url": "http://httpbin/",
      "strip_listen_path": true
    },
    "active": true,
    "notifications": { "shared_secret": "", "oauth_on_keychange_url": "" },
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
# Fetch the actual Tyk API ID from the created document
API_ID=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis/$DOC_ID" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['api_definition']['api_id'])")
echo "    created API ID: $API_ID (doc: $DOC_ID)"

echo ">>> Step 4: Create access policy for the OAuth Demo API"
POLICY_DEF="{\"rate\":1000,\"per\":60,\"quota_max\":-1,\"quota_renewal_rate\":-1,\"access_rights\":{\"$API_ID\":{\"api_id\":\"$API_ID\",\"api_name\":\"OAuth Demo API\",\"versions\":[\"Default\"]}},\"org_id\":\"$ORG_ID\",\"active\":true,\"name\":\"OAuth Demo Policy\",\"tags\":[],\"is_inactive\":false}"
POLICY_RESP=$(curl -sf -X POST "$DASHBOARD_URL/api/portal/policies" \
  -H "Authorization: $USER_KEY" \
  -H "Content-Type: application/json" \
  -d "$POLICY_DEF")
POLICY_ID=$(echo "$POLICY_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('_id', d.get('Message','?')))")
echo "    created policy ID: $POLICY_ID"

echo ">>> Step 5: Hot reload gateway"
curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
  -H "x-tyk-authorization: $GATEWAY_SECRET" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('    status:', d.get('status','?'))"
echo "    waiting 3s for API to become available..."
sleep 3

echo ">>> Step 6: Create OAuth clients (with policy)"
CLIENTS=("client-alpha" "client-beta" "client-gamma")
for CID in "${CLIENTS[@]}"; do
  SECRET="secret-${CID}"
  PAYLOAD="{\"api_id\":\"$API_ID\",\"client_id\":\"$CID\",\"secret\":\"$SECRET\",\"redirect_uri\":\"http://localhost\",\"policy_id\":\"$POLICY_ID\"}"
  CRESP=$(curl -sf -X POST "$DASHBOARD_URL/api/apis/oauth/$API_ID" \
    -H "Authorization: $USER_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  echo "    created: $(echo "$CRESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('client_id','?'))")"
done

echo ">>> Step 7: Get access tokens"
TOKEN_ALPHA=""
TOKEN_BETA=""
TOKEN_GAMMA=""
for CID in "${CLIENTS[@]}"; do
  SECRET="secret-${CID}"
  BASIC=$(echo -n "$CID:$SECRET" | base64)
  TRESP=$(curl -sf -X POST "$GATEWAY_URL$LISTEN_PATH/oauth/token/" \
    -H "Authorization: Basic $BASIC" \
    -d "grant_type=client_credentials")
  TOKEN=$(echo "$TRESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
  echo "    $CID: ${TOKEN:0:20}..."
  case "$CID" in
    "client-alpha") TOKEN_ALPHA="$TOKEN" ;;
    "client-beta")  TOKEN_BETA="$TOKEN"  ;;
    "client-gamma") TOKEN_GAMMA="$TOKEN" ;;
  esac
done
TOKENS=("$TOKEN_ALPHA" "$TOKEN_BETA" "$TOKEN_GAMMA")

echo ">>> Step 8: Generate success traffic (60 requests, ~0.5s apart for OTLP visibility)"
for i in $(seq 0 59); do
  curl -s -H "Authorization: Bearer ${TOKENS[$((i % 3))]}" \
    "$GATEWAY_URL$LISTEN_PATH/get" -o /dev/null && printf "."
  sleep 0.5
done
echo " done"

echo ">>> Step 9: Generate error traffic (15 requests → HTTP 500, ~1s apart)"
for i in $(seq 0 14); do
  curl -s -H "Authorization: Bearer ${TOKENS[$((i % 3))]}" \
    "$GATEWAY_URL$LISTEN_PATH/status/500" -o /dev/null && printf "e"
  sleep 1
done
echo " done"

echo ""
echo "OAuth traffic generated successfully!"
echo "  API ID   : $API_ID"
echo "  Clients  : ${CLIENTS[*]}"
echo "  Requests : 60 success + 15 errors (~60s total — counter increments across OTLP export cycles)"
echo ""
echo "Wait ~10s for the OTLP export interval, then check Grafana:"
echo "  Panel 123 — OAuth Client Traffic"
echo "  Panel 124 — OAuth Client Error Rate (Top 10)"
echo ""
echo "Verify in Prometheus:"
echo "  tyk_requests_by_oauth_total{service_name=\"tyk-gateway\"}"
