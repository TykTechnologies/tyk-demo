#!/usr/bin/env bash
# Demonstrates quota, rate limiting, and cache hit effects to populate:
#   tyk_requests_with_cache_total{cache_status="1"} → panels 141-143
#   tyk_requests_by_quota_limit_total{quota_limit=...} → panel 174
#   tyk_api_requests_total{http_response_status_code="429"} → panels 171-173
#
# Usage: bash scripts/traffic-control-demo.sh
#
# Prerequisites: tyk-demo stack running (./up.sh tyk)
# Re-runnable: cleans up stale APIs before creating new ones
set -euo pipefail

DASHBOARD_URL="http://localhost:3000"
GATEWAY_URL="http://localhost:8080"
GATEWAY_SECRET="28d220fd77974a4facfb07dc1e49c2aa"
CACHE_PATH="/cache-demo"
QUOTA_PATH="/quota-demo"

echo ">>> Step 1: Get Dashboard user API key and org_id"
BOOTSTRAP_LOG="logs/bootstrap.log"
if [[ ! -f "$BOOTSTRAP_LOG" ]]; then
  echo "ERROR: $BOOTSTRAP_LOG not found. Run ./up.sh tyk first."
  exit 1
fi
USER_KEY=$(grep -A5 "Creating Dashboard User: admin-user@example.org" "$BOOTSTRAP_LOG" | grep "API Key:" | tail -1 | awk '{print $NF}')
if [[ -z "$USER_KEY" ]]; then
  echo "ERROR: Could not extract API key from $BOOTSTRAP_LOG"
  exit 1
fi
USER_RESP=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/users")
ORG_ID=$(echo "$USER_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['users'][0]['org_id'])")
echo "    user key: $USER_KEY  org: $ORG_ID"

echo ">>> Step 2: Delete stale APIs on $CACHE_PATH and $QUOTA_PATH"
STALE=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis?p=-1" | \
  python3 -c "
import sys,json
apis=json.load(sys.stdin)['apis']
paths=['$CACHE_PATH/', '$QUOTA_PATH/']
ids=[a['api_definition']['api_id'] for a in apis if a['api_definition'].get('proxy',{}).get('listen_path','') in paths]
print(' '.join(ids))
")
for OLD_ID in $STALE; do
  curl -sf -X DELETE "$DASHBOARD_URL/api/apis/$OLD_ID" -H "Authorization: $USER_KEY" > /dev/null
  echo "    deleted stale API: $OLD_ID"
done

# Delete stale policies
for PNAME in "Cache Demo Policy" "Quota Low Policy" "Quota Mid Policy" "Quota High Policy"; do
  STALE_POLS=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/portal/policies?p=-1" | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
ids=[p['_id'] for p in d.get('Data',[]) if p.get('name') == '$PNAME']
print(' '.join(ids))
")
  for OLD_PID in $STALE_POLS; do
    curl -sf -X DELETE "$DASHBOARD_URL/api/portal/policies/$OLD_PID" -H "Authorization: $USER_KEY" > /dev/null
    echo "    deleted stale policy: $OLD_PID ($PNAME)"
  done
done

echo ">>> Step 3: Create Cache Demo API (keyless, caching enabled)"
CACHE_API_DEF=$(cat <<EOF
{
  "api_definition": {
    "name": "Cache Demo API",
    "slug": "cache-demo",
    "api_id": "",
    "org_id": "$ORG_ID",
    "use_keyless": true,
    "proxy": {
      "listen_path": "$CACHE_PATH/",
      "target_url": "http://httpbin/",
      "strip_listen_path": true
    },
    "active": true,
    "cache_options": {
      "cache_timeout": 60,
      "enable_cache": true,
      "cache_all_safe_requests": true,
      "cache_response_codes": [200]
    },
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
CACHE_CREATE=$(curl -sf -X POST "$DASHBOARD_URL/api/apis" \
  -H "Authorization: $USER_KEY" -H "Content-Type: application/json" \
  -d "$CACHE_API_DEF")
CACHE_DOC=$(echo "$CACHE_CREATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['Meta'])")
CACHE_API_ID=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis/$CACHE_DOC" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['api_definition']['api_id'])")
echo "    cache API ID: $CACHE_API_ID"

echo ">>> Step 4: Create Quota Demo API (key auth required)"
QUOTA_API_DEF=$(cat <<EOF
{
  "api_definition": {
    "name": "Quota Demo API",
    "slug": "quota-demo",
    "api_id": "",
    "org_id": "$ORG_ID",
    "use_keyless": false,
    "use_oauth2": false,
    "auth": { "auth_header_name": "x-api-key" },
    "proxy": {
      "listen_path": "$QUOTA_PATH/",
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
QUOTA_CREATE=$(curl -sf -X POST "$DASHBOARD_URL/api/apis" \
  -H "Authorization: $USER_KEY" -H "Content-Type: application/json" \
  -d "$QUOTA_API_DEF")
QUOTA_DOC=$(echo "$QUOTA_CREATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['Meta'])")
QUOTA_API_ID=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis/$QUOTA_DOC" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['api_definition']['api_id'])")
echo "    quota API ID: $QUOTA_API_ID"

echo ">>> Step 5: Hot reload gateway"
curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
  -H "x-tyk-authorization: $GATEWAY_SECRET" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('    status:', d.get('status','?'))"
echo "    waiting 3s..."
sleep 3

echo ">>> Step 6: Create 3 policies with different quota tiers"
make_policy() {
  local NAME="$1" QUOTA="$2" RATE="$3" PER="$4"
  local DEF="{\"rate\":$RATE,\"per\":$PER,\"quota_max\":$QUOTA,\"quota_renewal_rate\":3600,\"access_rights\":{\"$QUOTA_API_ID\":{\"api_id\":\"$QUOTA_API_ID\",\"api_name\":\"Quota Demo API\",\"versions\":[\"Default\"]}},\"org_id\":\"$ORG_ID\",\"active\":true,\"name\":\"$NAME\",\"tags\":[],\"is_inactive\":false}"
  curl -sf -X POST "$DASHBOARD_URL/api/portal/policies" \
    -H "Authorization: $USER_KEY" -H "Content-Type: application/json" \
    -d "$DEF" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('_id', d.get('Message','?')))"
}
POL_LOW=$(make_policy "Quota Low Policy" 30 2 1)
POL_MID=$(make_policy "Quota Mid Policy" 100 10 1)
POL_HIGH=$(make_policy "Quota High Policy" 500 50 1)
echo "    policies: low=$POL_LOW  mid=$POL_MID  high=$POL_HIGH"

echo ">>> Step 6b: Hot reload gateway to sync new policies"
curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
  -H "x-tyk-authorization: $GATEWAY_SECRET" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('    status:', d.get('status','?'))"
echo "    waiting 2s..."
sleep 2

echo ">>> Step 7: Create 3 API keys (one per policy)"
make_key() {
  local POL_ID="$1"
  # Full session object required — minimal payload with apply_policy_id causes empty response
  local PAYLOAD="{\"apply_policy_id\":\"$POL_ID\",\"org_id\":\"$ORG_ID\",\"allowance\":0,\"rate\":0,\"per\":0,\"expires\":-1,\"quota_max\":-1,\"quota_renewal_rate\":3600,\"quota_remaining\":-1,\"quota_renews\":0,\"is_inactive\":false,\"access_rights\":{}}"
  local RESP
  RESP=$(curl -s -X POST "$DASHBOARD_URL/api/keys" \
    -H "Authorization: $USER_KEY" -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  if [[ -z "$RESP" ]]; then
    echo "ERROR: Empty response from POST /api/keys" >&2; return 1
  fi
  echo "$RESP" | python3 -c "
import sys,json
d=json.load(sys.stdin)
k=d.get('key', d.get('key_id', d.get('key_hash','')))
if not k:
  import sys; print('ERROR: unexpected response:', d, file=sys.stderr); sys.exit(1)
print(k)
"
}
KEY_LOW=$(make_key "$POL_LOW")
KEY_MID=$(make_key "$POL_MID")
KEY_HIGH=$(make_key "$POL_HIGH")
echo "    key-low:  $KEY_LOW"
echo "    key-mid:  $KEY_MID"
echo "    key-high: $KEY_HIGH"

echo ""
echo "========================================================"
echo ">>> Scenario 1: Cache hit/miss (20 requests, same path)"
echo "========================================================"
echo "    First request should be cache MISS; remaining should be HITs"
echo ""
for i in $(seq 1 20); do
  CACHED=$(curl -si -H "x-request-id: cache-test" \
    "$GATEWAY_URL$CACHE_PATH/get" 2>/dev/null | \
    grep -i "x-tyk-cached-response" | tr -d '\r' | awk '{print $2}') || true
  if [[ -z "$CACHED" ]]; then
    printf "  [%02d] MISS\n" "$i"
  else
    printf "  [%02d] HIT  (X-Tyk-Cached-Response: %s)\n" "$i" "$CACHED"
  fi
  sleep 0.2
done
echo ""
echo "    Cache traffic done — check panels 141-143 after ~10s"

echo ""
echo "========================================================"
echo ">>> Scenario 2: Quota tier traffic (15 req × 3 keys, sleep 0.5s)"
echo "    Populates tyk_requests_by_quota_limit_total with 3 quota_limit values"
echo "========================================================"
for i in $(seq 1 15); do
  RL_LOW=$(curl -si -H "x-api-key: $KEY_LOW" "$GATEWAY_URL$QUOTA_PATH/get" 2>/dev/null | \
    grep -i "x-ratelimit-remaining:" | tr -d '\r' | awk '{print $2}') || true
  RL_MID=$(curl -si -H "x-api-key: $KEY_MID" "$GATEWAY_URL$QUOTA_PATH/get" 2>/dev/null | \
    grep -i "x-ratelimit-remaining:" | tr -d '\r' | awk '{print $2}') || true
  RL_HIGH=$(curl -si -H "x-api-key: $KEY_HIGH" "$GATEWAY_URL$QUOTA_PATH/get" 2>/dev/null | \
    grep -i "x-ratelimit-remaining:" | tr -d '\r' | awk '{print $2}') || true
  printf "  [%02d] remaining — low: %-4s  mid: %-4s  high: %s\n" "$i" "$RL_LOW" "$RL_MID" "$RL_HIGH"
  sleep 0.5
done
echo ""
echo "    Quota tier traffic done"

echo ""
echo "========================================================"
echo ">>> Scenario 3: Quota exhaustion (35 rapid requests with key-low, quota=30)"
echo "    Requests 1-30 succeed; requests 31-35 should return 429"
echo "========================================================"
for i in $(seq 1 35); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "x-api-key: $KEY_LOW" \
    "$GATEWAY_URL$QUOTA_PATH/get")
  if [[ "$STATUS" == "429" ]]; then
    printf "  [%02d] 429 QUOTA EXHAUSTED\n" "$i"
  else
    printf "  [%02d] %s\n" "$i" "$STATUS"
  fi
done
echo ""
echo "    Quota exhaustion done"

echo ""
echo "========================================================"
echo ">>> Scenario 4: Rate limit burst (15 rapid requests with key-mid, rate=10/s)"
echo "    Rapid fire with no sleep — some will hit the per-second rate limit"
echo "========================================================"
RATE_429=0
for i in $(seq 1 15); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "x-api-key: $KEY_MID" \
    "$GATEWAY_URL$QUOTA_PATH/get")
  if [[ "$STATUS" == "429" ]]; then
    RATE_429=$((RATE_429 + 1))
    printf "  [%02d] 429 RATE LIMITED\n" "$i"
  else
    printf "  [%02d] %s\n" "$i" "$STATUS"
  fi
done
echo ""
echo "    Rate limit burst done. Got $RATE_429 x 429 responses."

echo ""
echo "========================================================"
echo "Traffic control demo complete!"
echo "  Cache API ID : $CACHE_API_ID"
echo "  Quota API ID : $QUOTA_API_ID"
echo "  Quota tiers  : low(30)=$KEY_LOW  mid(100)=$KEY_MID  high(500)=$KEY_HIGH"
echo ""
echo "Wait ~10s for OTLP export, then check Grafana:"
echo "  Panel 141 — Cache Hit Rate               (target: ~95% hit after warm-up)"
echo "  Panel 142 — Cache Status Over Time       (1=cached, 0=uncached)"
echo "  Panel 143 — Cache Status Breakdown"
echo "  Panel 171 — 429 Rejection %"
echo "  Panel 172 — 429 Rejections Over Time"
echo "  Panel 173 — Top APIs by 429 Rejections"
echo "  Panel 174 — Traffic by Quota Tier        (3 lines: quota_limit=30/100/500)"
echo ""
echo "Verify in Prometheus:"
echo "  tyk_requests_with_cache_total{service_name=\"tyk-gateway\"}"
echo "  tyk_requests_by_quota_limit_total{service_name=\"tyk-gateway\"}"
echo "  tyk_api_requests_total{service_name=\"tyk-gateway\", http_response_status_code=\"429\"}"
