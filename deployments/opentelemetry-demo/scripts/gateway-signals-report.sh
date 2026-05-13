#!/usr/bin/env bash
# gateway-signals-report.sh
#
# Provisions a test API in Tyk Gateway, runs auth-failure and traffic-control
# scenarios, captures gateway system logs, Prometheus metrics (before/after
# delta), and Jaeger traces, then writes a Markdown report.
#
# Each scenario is immediately followed by its own signals:
#   results → gateway logs → prometheus metrics → jaeger traces
#
# Usage: bash deployments/opentelemetry-demo/scripts/gateway-signals-report.sh
#
# Prerequisites:
#   - tyk-demo stack and opentelemetry-demo running (for Jaeger, optional) running:  ./up.sh opentelemetry-demo
#   - docker, curl, python3 available
# Re-runnable: cleans up stale test resources before each run.

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
DASHBOARD_URL="http://localhost:3000"
GATEWAY_URL="http://localhost:8080"
GATEWAY_SECRET="28d220fd77974a4facfb07dc1e49c2aa"
PROMETHEUS_API="http://localhost:9090"
JAEGER_URL="http://localhost:8085/jaeger/ui/api/traces"
GW_CONTAINER="tyk-demo-tyk-gateway-1"

TEST_API_PATH="/report-test"
BOOTSTRAP_LOG="logs/bootstrap.log"
REPORTS_DIR="reports"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_FILE="${REPORTS_DIR}/gateway-signals-report-${TIMESTAMP}.md"

# Global scenario result arrays (populated by run_and_capture_scenario)
S0_RESULTS=() S1_RESULTS=() S2_RESULTS=() S3_RESULTS=() S4_RESULTS=()
S5_RESULTS=() S6_RESULTS=() S7_RESULTS=() S8_RESULTS=() S9_RESULTS=()

# Global state set during run_all_scenarios, read by write_report
TEST_START=""
TEST_START_EPOCH=""
TOTAL_LOG_LINES=0
METRICS_OK=false
STATUS_OK=false

# ─── Prereq checks ────────────────────────────────────────────────────────────
check_prereqs() {
  echo ">>> Checking prerequisites"
  for cmd in docker curl python3; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "ERROR: '$cmd' is required but not found." >&2; exit 1
    fi
  done
  if [[ ! -f "$BOOTSTRAP_LOG" ]]; then
    echo "ERROR: $BOOTSTRAP_LOG not found. Run ./up.sh opentelemetry-demo first." >&2; exit 1
  fi
  if ! curl -sf "$GATEWAY_URL/hello" >/dev/null 2>&1; then
    echo "ERROR: Gateway not reachable at $GATEWAY_URL" >&2; exit 1
  fi
  mkdir -p "$REPORTS_DIR"
  echo "    OK"
}

# ─── Credentials ──────────────────────────────────────────────────────────────
get_credentials() {
  echo ">>> Getting credentials"
  USER_KEY=$(grep "API Key:" "$BOOTSTRAP_LOG" | head -1 | awk '{print $NF}')
  if [[ -z "$USER_KEY" ]]; then
    echo "ERROR: Could not extract API key from $BOOTSTRAP_LOG" >&2; exit 1
  fi
  USER_RESP=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/users")
  ORG_ID=$(echo "$USER_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['users'][0]['org_id'])")
  echo "    user key: ${USER_KEY:0:8}...  org: $ORG_ID"
}

# ─── Cleanup ──────────────────────────────────────────────────────────────────
cleanup_stale() {
  echo ">>> Cleaning up stale test resources"

  # Delete stale APIs on the test path
  STALE_APIS=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis?p=-1" | \
    python3 -c "
import sys,json
apis=json.load(sys.stdin)['apis']
ids=[a['api_definition']['api_id'] for a in apis
     if a['api_definition'].get('proxy',{}).get('listen_path','') in ('$TEST_API_PATH/', '$TEST_API_PATH')]
print(' '.join(ids))
")
  for OLD_ID in $STALE_APIS; do
    curl -sf -X DELETE "$DASHBOARD_URL/api/apis/$OLD_ID" -H "Authorization: $USER_KEY" >/dev/null
    echo "    deleted stale API: $OLD_ID"
  done

  # Delete stale policies
  for PNAME in "Report Low Policy" "Report Mid Policy" "Report Slow Policy"; do
    STALE_POLS=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/portal/policies?p=-1" | \
      python3 -c "
import sys,json
d=json.load(sys.stdin)
ids=[p['_id'] for p in d.get('Data',[]) if p.get('name') == '$PNAME']
print(' '.join(ids))
")
    for OLD_PID in $STALE_POLS; do
      curl -sf -X DELETE "$DASHBOARD_URL/api/portal/policies/$OLD_PID" -H "Authorization: $USER_KEY" >/dev/null
      echo "    deleted stale policy: $OLD_PID ($PNAME)"
    done
  done
}

# ─── Create test API ──────────────────────────────────────────────────────────
create_test_api() {
  echo ">>> Creating test API (key-auth)"
  API_DEF=$(cat <<EOF
{
  "api_definition": {
    "name": "Report Test API",
    "slug": "report-test",
    "api_id": "",
    "org_id": "$ORG_ID",
    "use_keyless": false,
    "use_oauth2": false,
    "auth": { "auth_header_name": "x-api-key" },
    "proxy": {
      "listen_path": "$TEST_API_PATH/",
      "target_url": "http://httpbin.org/anything/",
      "strip_listen_path": true
    },
    "active": true,
    "enable_detailed_recording": true,
    "version_data": {
      "not_versioned": true,
      "default_version": "Default",
      "versions": {
        "Default": {
          "name": "Default",
          "expires": "",
          "paths": {
            "ignored": [],
            "white_list": [],
            "black_list": []
          },
          "use_extended_paths": true,
          "global_headers": {},
          "global_headers_remove": [],
          "global_headers_disabled": false,
          "global_response_headers": {},
          "global_response_headers_remove": [],
          "global_response_headers_disabled": false,
          "ignore_endpoint_case": false,
          "global_size_limit": 0,
          "global_size_limit_disabled": false,
          "override_target": "",
          "extended_paths": {
            "track_endpoints": [
              {
                "disabled": false,
                "path": "/path2",
                "method": "GET"
              },
              {
                "disabled": false,
                "path": "/path1",
                "method": "GET"
              },
              {
                "disabled": false,
                "path": "/{id}",
                "method": "GET"
              }
            ]
          }
        }
      }
    }
  },
  "hook_references": [], "is_site": false, "sort_by": 0,
  "user_group_owners": [], "user_owners": []
}
EOF
)
  CREATE_RESP=$(curl -sf -X POST "$DASHBOARD_URL/api/apis" \
    -H "Authorization: $USER_KEY" -H "Content-Type: application/json" \
    -d "$API_DEF")
  API_DOC_ID=$(echo "$CREATE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['Meta'])")
  TEST_API_ID=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis/$API_DOC_ID" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['api_definition']['api_id'])")
  echo "    API ID: $TEST_API_ID"

  echo ">>> Hot reloading gateway"
  curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
    -H "x-tyk-authorization: $GATEWAY_SECRET" >/dev/null
  sleep 2
}

# ─── Create policies ──────────────────────────────────────────────────────────
create_policies() {
  echo ">>> Creating policies"
  make_policy() {
    local NAME="$1" QUOTA="$2" RATE="$3" PER="$4"
    local DEF="{\"rate\":$RATE,\"per\":$PER,\"quota_max\":$QUOTA,\"quota_renewal_rate\":3600,\"access_rights\":{\"$TEST_API_ID\":{\"api_id\":\"$TEST_API_ID\",\"api_name\":\"Report Test API\",\"versions\":[\"Default\"]}},\"org_id\":\"$ORG_ID\",\"active\":true,\"name\":\"$NAME\",\"tags\":[],\"is_inactive\":false}"
    curl -sf -X POST "$DASHBOARD_URL/api/portal/policies" \
      -H "Authorization: $USER_KEY" -H "Content-Type: application/json" \
      -d "$DEF" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('_id', d.get('Message','?')))"
  }
  POL_LOW=$(make_policy "Report Low Policy" 30 100 1)    # quota=30, rate=100/s (quota limits S3)
  POL_MID=$(make_policy "Report Mid Policy" 1000 10 1)   # quota=1000, rate=10/s (rate limits S4/S9)
  POL_SLOW=$(make_policy "Report Slow Policy" 100 50 1)  # quota=100, rate=50/s (fresh key for R07)
  echo "    pol-low: $POL_LOW"
  echo "    pol-mid: $POL_MID"
  echo "    pol-slow: $POL_SLOW"

  echo ">>> Hot reloading gateway to sync policies"
  curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
    -H "x-tyk-authorization: $GATEWAY_SECRET" >/dev/null
  sleep 2
}

# ─── Create keys ──────────────────────────────────────────────────────────────
create_keys() {
  echo ">>> Creating keys"
  make_key() {
    local POL_ID="$1"
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
  KEY_SLOW=$(make_key "$POL_SLOW")
  echo "    key-low: ${KEY_LOW:0:12}..."
  echo "    key-mid: ${KEY_MID:0:12}..."
  echo "    key-slow: ${KEY_SLOW:0:12}..."
}

# ─── Prometheus snapshot ──────────────────────────────────────────────────────
snapshot_prometheus() {
  # Query all metrics for service_name="tyk-gateway" via Prometheus instant-query API,
  # save as TSV: metric_key<TAB>value
  # Optional second arg: api_id_filter — only keep series where tyk_api_id or api_id matches
  local outfile="$1"
  local api_id_filter="${2:-}"
  local tmp_json="/tmp/prom_query_$$.json"
  curl -s "${PROMETHEUS_API}/api/v1/query?query=%7Bservice_name%3D%22tyk-gateway%22%7D" \
    -o "$tmp_json" 2>/dev/null || true
  if [[ ! -s "$tmp_json" ]]; then
    echo "  WARN: Prometheus query returned empty response" >&2
    : > "$outfile"
    rm -f "$tmp_json"
    return
  fi
  python3 -c "
import sys, json

json_file      = sys.argv[1]
outfile        = sys.argv[2]
api_id_filter  = sys.argv[3] if len(sys.argv) > 3 else ''
try:
    with open(json_file) as f:
        d = json.load(f)
except Exception as e:
    print(f'  WARN: Prometheus parse failed: {e}', file=sys.stderr)
    open(outfile, 'w').close()
    sys.exit(0)

results = d.get('data', {}).get('result', [])
rows = []
for r in results:
    m = r['metric']
    if api_id_filter:
        metric_api_id = m.get('tyk_api_id', m.get('api_id', ''))
        if metric_api_id != api_id_filter:
            continue
    name = m.get('__name__', '')
    keep = {k: v for k, v in m.items() if k not in ('__name__', 'instance',
        'job', 'service_instance_id', 'service_namespace', 'host_name', 'service_version')}
    label_str = ','.join(f'{k}=\"{v}\"' for k, v in sorted(keep.items()))
    key = f'{name}{{{label_str}}}'
    val = float(r['value'][1])
    rows.append((key, val))

with open(outfile, 'w') as f:
    for key, val in rows:
        f.write(f'{key}\t{val:.0f}\n')
" "$tmp_json" "$outfile" "$api_id_filter"
  rm -f "$tmp_json"
}

# ─── Compute metric delta ─────────────────────────────────────────────────────
compute_metric_delta() {
  # Args: before_file after_file
  # Returns tab-separated lines: metric_key <TAB> before <TAB> after <TAB> delta
  local before="$1"
  local after="$2"
  python3 - <<'PYEOF' "$before" "$after"
import sys

def load(path):
    result = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                parts = line.rsplit('\t', 1)
                if len(parts) == 2:
                    result[parts[0]] = float(parts[1])
    except FileNotFoundError:
        pass
    return result

before = load(sys.argv[1])
after  = load(sys.argv[2])

all_keys = sorted(set(list(before.keys()) + list(after.keys())))
for k in all_keys:
    b = before.get(k, 0.0)
    a = after.get(k, 0.0)
    d = a - b
    if d != 0:
        print(f"{k}\t{b:.0f}\t{a:.0f}\t{d:+.0f}")
PYEOF
}

# ─── Scenario result table ────────────────────────────────────────────────────
scenario_table() {
  printf "| Req # | Status |\n|-------|--------|\n"
  local i=1
  for s in "$@"; do
    printf "| %d | %s |\n" "$i" "$s"
    ((i++))
  done
}

# ─── Verification helpers ─────────────────────────────────────────────────────
all_equal() {
  local expected="$1"; shift
  for v in "$@"; do [[ "$v" != "$expected" ]] && return 1; done
  return 0
}

contains_429() {
  for v in "$@"; do [[ "$v" == "429" ]] && return 0; done
  return 1
}

count_value() {
  local target="$1"; shift
  local n=0
  for v in "$@"; do [[ "$v" == "$target" ]] && ((n++)) || true; done
  echo "$n"
}

check_mark() {
  [[ "$1" == "true" ]] && echo "x" || echo " "
}

# ─── Per-scenario: run traffic + capture signals + write section ──────────────
run_and_capture_scenario() {
  local n="$1"

  # Per-scenario temp files
  local tmp_before="/tmp/report_s${n}_before_${TIMESTAMP}.txt"
  local tmp_after="/tmp/report_s${n}_after_${TIMESTAMP}.txt"
  local tmp_logs="/tmp/report_s${n}_logs_${TIMESTAMP}.txt"
  local tmp_filtered="/tmp/report_s${n}_filtered_${TIMESTAMP}.txt"
  local section_file="/tmp/report_section_${n}_${TIMESTAMP}.md"

  # Scenario metadata
  local s_name s_desc
  case "$n" in
    0) s_name="S0: Valid Requests (baseline)"
       s_desc="5 requests with a valid key (key-mid). Expected: all **200**." ;;
    1) s_name="S1 · R03a: Auth Failure — Missing Header (AMF)"
       s_desc="5 requests with no \`x-api-key\` header. Expected: all **401** (\`response_flag: AMF\`)." ;;
    2) s_name="S2 · R03b: Auth Failure — Invalid Key (AKI)"
       s_desc="5 requests with \`x-api-key: invalid-key-xyz\`. Expected: all **403** (\`response_flag: AKI\`)." ;;
    3) s_name="S3 · R04: Quota Exhaustion (QEX)"
       s_desc="35 requests with key-low (quota=30). Expected: first 30 → **200**, last 5 → **403** (\`response_flag: QEX\`)." ;;
    4) s_name="S4 · R05: Rate Limit Rejections (RLT)"
       s_desc="20 rapid requests with key-mid (rate=10/s). Expected: at least one **429** (\`response_flag: RLT\`)." ;;
    5) s_name="S5 · R01: High Error Rate"
       s_desc="20 requests: 5 valid (key-mid) + 15 with no key. Expected: ~75% error rate (≥15 × **401**)." ;;
    6) s_name="S6 · R02: Upstream Latency Spike"
       s_desc="5 requests to \`/delay/2\` via key-mid. Expected: all **200** with \`upstream_latency≈2000ms\`; \`latency_gateway\` stays small — spike is upstream." ;;
    7) s_name="S7 · R06: Upstream 5xx Errors"
       s_desc="10 requests to \`/status/500\` via key-mid. Expected: all **500** passed through from upstream." ;;
    8) s_name="S8 · R07: Tenant Latency Anomaly"
       s_desc="5 requests with key-mid → \`/get\` (fast tenant) + 5 with key-slow → \`/delay/1\` (slow tenant). Compare per-key latency in logs and traces." ;;
    9) s_name="S9 · R08: Runtime Metrics Under Load"
       s_desc="50 rapid requests with key-mid. Observe Go runtime metrics (goroutines, heap) in Prometheus delta. Many **429**s expected." ;;
  esac

  echo ""
  echo "========================================================"
  echo ">>> $s_name"
  echo "========================================================"

  # (1) Prometheus before snapshot
  snapshot_prometheus "$tmp_before" "$TEST_API_ID"
  local s_start s_start_epoch
  s_start=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  s_start_epoch=$(date -u +%s)

  # (2) Run scenario traffic
  case "$n" in
    0)
      S0_RESULTS=()
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/S0")
        S0_RESULTS+=("$STATUS")
        printf "  [%02d] %s\n" "$i" "$STATUS"
        sleep 0.2
      done
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/path1")
        S0_RESULTS+=("$STATUS")
        printf "  [%02d] %s\n" "$i" "$STATUS"
        sleep 0.2
      done
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/path2")
        S0_RESULTS+=("$STATUS")
        printf "  [%02d] %s\n" "$i" "$STATUS"
        sleep 0.2
      done
      ;;
    1)
      S1_RESULTS=()
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL$TEST_API_PATH/S1")
        S1_RESULTS+=("$STATUS")
        printf "  [%02d] %s\n" "$i" "$STATUS"
        sleep 0.2
      done
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL$TEST_API_PATH/path1")
        S1_RESULTS+=("$STATUS")
        printf "  [%02d] %s\n" "$i" "$STATUS"
        sleep 0.2
      done
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL$TEST_API_PATH/path2")
        S1_RESULTS+=("$STATUS")
        printf "  [%02d] %s\n" "$i" "$STATUS"
        sleep 0.2
      done
      ;;
    2)
      S2_RESULTS=()
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: invalid-key-xyz" "$GATEWAY_URL$TEST_API_PATH/S2")
        S2_RESULTS+=("$STATUS")
        printf "  [%02d] %s\n" "$i" "$STATUS"
        sleep 0.2
      done
            for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: invalid-key-xyz" "$GATEWAY_URL$TEST_API_PATH/path1")
        S2_RESULTS+=("$STATUS")
        printf "  [%02d] %s\n" "$i" "$STATUS"
        sleep 0.2
      done
            for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: invalid-key-xyz" "$GATEWAY_URL$TEST_API_PATH/path2")
        S2_RESULTS+=("$STATUS")
        printf "  [%02d] %s\n" "$i" "$STATUS"
        sleep 0.2
      done
      ;;
    3)
      S3_RESULTS=()
      for i in $(seq 1 35); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_LOW" "$GATEWAY_URL$TEST_API_PATH/S3")
        S3_RESULTS+=("$STATUS")
        if [[ "$STATUS" == "403" ]]; then
          printf "  [%02d] 403 QUOTA EXCEEDED\n" "$i"
        elif [[ "$STATUS" == "429" ]]; then
          printf "  [%02d] 429 RATE LIMITED\n" "$i"
        else
          printf "  [%02d] %s\n" "$i" "$STATUS"
        fi
      done
      for i in $(seq 1 35); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_LOW" "$GATEWAY_URL$TEST_API_PATH/path1")
        S3_RESULTS+=("$STATUS")
        if [[ "$STATUS" == "403" ]]; then
          printf "  [%02d] 403 QUOTA EXCEEDED\n" "$i"
        elif [[ "$STATUS" == "429" ]]; then
          printf "  [%02d] 429 RATE LIMITED\n" "$i"
        else
          printf "  [%02d] %s\n" "$i" "$STATUS"
        fi
      done
      for i in $(seq 1 35); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_LOW" "$GATEWAY_URL$TEST_API_PATH/path2")
        S3_RESULTS+=("$STATUS")
        if [[ "$STATUS" == "403" ]]; then
          printf "  [%02d] 403 QUOTA EXCEEDED\n" "$i"
        elif [[ "$STATUS" == "429" ]]; then
          printf "  [%02d] 429 RATE LIMITED\n" "$i"
        else
          printf "  [%02d] %s\n" "$i" "$STATUS"
        fi
      done
      ;;
    4)
      S4_RESULTS=()
      for i in $(seq 1 20); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/S4")
        S4_RESULTS+=("$STATUS")
        if [[ "$STATUS" == "429" ]]; then
          printf "  [%02d] 429 RATE LIMITED\n" "$i"
        else
          printf "  [%02d] %s\n" "$i" "$STATUS"
        fi
      done
      for i in $(seq 1 20); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/path1")
        S4_RESULTS+=("$STATUS")
        if [[ "$STATUS" == "429" ]]; then
          printf "  [%02d] 429 RATE LIMITED\n" "$i"
        else
          printf "  [%02d] %s\n" "$i" "$STATUS"
        fi
      done
      for i in $(seq 1 20); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/path2")
        S4_RESULTS+=("$STATUS")
        if [[ "$STATUS" == "429" ]]; then
          printf "  [%02d] 429 RATE LIMITED\n" "$i"
        else
          printf "  [%02d] %s\n" "$i" "$STATUS"
        fi
      done
      ;;
    5)
      S5_RESULTS=()
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/S5")
        S5_RESULTS+=("$STATUS"); printf "  [%02d] %s (valid)\n" "$i" "$STATUS"; sleep 0.1
      done
      for i in $(seq 6 20); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL$TEST_API_PATH/S5")
        S5_RESULTS+=("$STATUS"); printf "  [%02d] %s (no-key)\n" "$i" "$STATUS"; sleep 0.1
      done
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/path1")
        S5_RESULTS+=("$STATUS"); printf "  [%02d] %s (valid)\n" "$i" "$STATUS"; sleep 0.1
      done
      for i in $(seq 6 20); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL$TEST_API_PATH/path1")
        S5_RESULTS+=("$STATUS"); printf "  [%02d] %s (no-key)\n" "$i" "$STATUS"; sleep 0.1
      done
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/path2")
        S5_RESULTS+=("$STATUS"); printf "  [%02d] %s (valid)\n" "$i" "$STATUS"; sleep 0.1
      done
      for i in $(seq 6 20); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL$TEST_API_PATH/path2")
        S5_RESULTS+=("$STATUS"); printf "  [%02d] %s (no-key)\n" "$i" "$STATUS"; sleep 0.1
      done
      ;;
    6)
      S6_RESULTS=()
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/delay/2")
        S6_RESULTS+=("$STATUS"); printf "  [%02d] %s\n" "$i" "$STATUS"
      done
      ;;
    7)
      S7_RESULTS=()
      for i in $(seq 1 10); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/status/500")
        S7_RESULTS+=("$STATUS"); printf "  [%02d] %s\n" "$i" "$STATUS"; sleep 0.1
      done
      ;;
    8)
      S8_RESULTS=()
      echo "  [key-mid -> /get (fast tenant)]"
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/get")
        S8_RESULTS+=("$STATUS"); printf "  [%02d] %s key-mid\n" "$i" "$STATUS"; sleep 0.2
      done
      echo "  [key-slow -> /delay/1 (slow tenant)]"
      for i in $(seq 6 10); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_SLOW" "$GATEWAY_URL$TEST_API_PATH/delay/1")
        S8_RESULTS+=("$STATUS"); printf "  [%02d] %s key-slow\n" "$i" "$STATUS"
      done
      ;;
    9)
      S9_RESULTS=()
      for i in $(seq 1 50); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "x-api-key: $KEY_MID" "$GATEWAY_URL$TEST_API_PATH/get")
        S9_RESULTS+=("$STATUS")
        if [[ "$STATUS" == "429" ]]; then
          printf "  [%02d] 429 RATE LIMITED\n" "$i"
        else
          printf "  [%02d] %s\n" "$i" "$STATUS"
        fi
      done
      ;;
  esac

  # (3) Wait for OTLP export flush
  echo "    Waiting 10s for OTLP export..."
  sleep 10
  local s_end_epoch
  s_end_epoch=$(date -u +%s)

  # (4) Prometheus after snapshot + compute delta
  snapshot_prometheus "$tmp_after" "$TEST_API_ID"
  local delta_output delta_table
  delta_output=$(compute_metric_delta "$tmp_before" "$tmp_after")
  delta_table=$(echo "$delta_output" | python3 -c "
import sys
rows = [l.split('\t') for l in sys.stdin if l.strip()]
if not rows:
    print('_No metric changes detected._')
    sys.exit(0)
print('| Metric | Before | After | Delta |')
print('|--------|--------|-------|-------|')
for r in rows:
    if len(r) == 4:
        print(f'| \`{r[0]}\` | {r[1]} | {r[2]} | {r[3]} |')
")

  # Update global checklist state
  [[ -n "$delta_output" ]] && METRICS_OK=true
  grep -qE '"401"|"403"|"429"' <<< "$delta_output" && STATUS_OK=true || true

  # (5) Gateway logs (access-log filter)
  docker logs "$GW_CONTAINER" --since "$s_start" > "$tmp_logs" 2>&1 || true
  python3 - <<'PYEOF' "$tmp_logs" "$tmp_filtered" "$TEST_API_ID"
import sys, json
src    = sys.argv[1]
dst    = sys.argv[2]
api_id = sys.argv[3] if len(sys.argv) > 3 else None
with open(src) as fin, open(dst, 'w') as fout:
    for line in fin:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
            if d.get('prefix') == 'access-log':
                if api_id is None or d.get('api_id') == api_id:
                    fout.write(line + '\n')
        except Exception:
            pass
PYEOF
  local n_log_lines
  n_log_lines=$(wc -l < "$tmp_filtered" | tr -d ' ')
  TOTAL_LOG_LINES=$((TOTAL_LOG_LINES + n_log_lines))
  local log_section
  if [[ "$n_log_lines" -gt 0 ]]; then
    log_section=$(cat "$tmp_filtered")
  else
    log_section="_(No access-log entries for this scenario.)_"
  fi

  # (6) Jaeger traces: query by time window, filter spans by operation containing TEST_API_PATH
  local start_us end_us jaeger_tmp jaeger_table
  start_us="${s_start_epoch}000000"
  end_us="${s_end_epoch}000000"
  jaeger_tmp="/tmp/report_s${n}_jaeger_${TIMESTAMP}.json"
  curl -sf "${JAEGER_URL}?service=tyk-gateway&start=${start_us}&end=${end_us}&limit=200" \
    -o "$jaeger_tmp" 2>/dev/null || echo '{"data":[]}' > "$jaeger_tmp"
  jaeger_table=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
api_path = sys.argv[2] if len(sys.argv) > 2 else ''
data = d.get('data', [])
if not data:
    print('_No traces found for this scenario._')
    sys.exit(0)
print('| Trace ID | Span ID | Operation | Duration | Span Attributes | Resource Attributes |')
print('|----------|---------|-----------|----------|-----------------|---------------------|')
count = 0
matched_tids = set()
for trace in data:
    tid_full = trace.get('traceID','')
    tid = tid_full[:8]
    processes = trace.get('processes', {})
    for span in trace.get('spans',[]):
        op = span.get('operationName','')
        if api_path and api_path not in op:
            continue
        matched_tids.add(tid_full)
        if count >= 100:
            continue
        sid = span.get('spanID','')[:8]
        dur = f\"{span.get('duration',0)/1000:.1f}ms\"
        span_tags = {t['key']: str(t.get('value','')) for t in span.get('tags',[])}
        proc = processes.get(span.get('processID',''), {})
        res_tags  = {t['key']: str(t.get('value','')) for t in proc.get('tags',[])}
        span_attrs = ', '.join(f'{k}={v}' for k,v in span_tags.items()) or '_none_'
        res_attrs  = ', '.join(f'{k}={v}' for k,v in res_tags.items())  or '_none_'
        print(f'| \`{tid}\` | \`{sid}\` | {op} | {dur} | {span_attrs} | {res_attrs} |')
        count += 1
print()
print(f'**Matched traces:** {len(matched_tids)} | **Matched spans:** {count}' + (' (capped at 100)' if count >= 100 else ''))
if not matched_tids:
    print()
    print(f'_No spans with operation containing \"{api_path}\" found._')
" "$jaeger_tmp" "$TEST_API_PATH" 2>/dev/null || echo "_Jaeger unavailable_")
  rm -f "$jaeger_tmp"

  # (7) Print scenario signal summary to terminal
  local delta_count
  delta_count=$(wc -l <<< "$delta_output" | tr -d ' ')
  local trace_summary
  trace_summary=$(grep -o 'Traces found: [0-9]*' <<< "$jaeger_table" || echo "unavailable")
  echo "    Logs: $n_log_lines access-log entries"
  echo "    Metrics: $delta_count series changed"
  echo "    Jaeger: $trace_summary"

  # (8) Build per-scenario result table (must happen after requests run in case block above)
  local results_table
  case "$n" in
    0) results_table=$(scenario_table "${S0_RESULTS[@]}") ;;
    1) results_table=$(scenario_table "${S1_RESULTS[@]}") ;;
    2) results_table=$(scenario_table "${S2_RESULTS[@]}") ;;
    3) results_table=$(scenario_table "${S3_RESULTS[@]}") ;;
    4) results_table=$(scenario_table "${S4_RESULTS[@]}") ;;
    5) results_table=$(scenario_table "${S5_RESULTS[@]}") ;;
    6) results_table=$(scenario_table "${S6_RESULTS[@]}") ;;
    7) results_table=$(scenario_table "${S7_RESULTS[@]}") ;;
    8) results_table=$(scenario_table "${S8_RESULTS[@]}") ;;
    9) results_table=$(scenario_table "${S9_RESULTS[@]}") ;;
  esac

  # (9) Write section file
  cat > "$section_file" <<SECTION
## $s_name

$s_desc

### Results

$results_table

### Gateway Log Entries

Filtered from \`docker logs $GW_CONTAINER --since $s_start\` (\`"prefix":"access-log"\` entries only).

$n_log_lines access-log entries captured.

\`\`\`
$log_section
\`\`\`

### Prometheus Metrics Delta

Source: \`${PROMETHEUS_API}/api/v1/query\` (\`{service_name="tyk-gateway"}\`) — non-zero delta only.

$delta_table

### Jaeger Traces

Service: \`tyk-gateway\` | Window: $s_start → $(date -u +"%Y-%m-%dT%H:%M:%SZ")

$jaeger_table

---
SECTION

  # (10) Cleanup per-scenario temp files
  rm -f "$tmp_before" "$tmp_after" "$tmp_logs" "$tmp_filtered"
}

# ─── Run all scenarios ────────────────────────────────────────────────────────
run_all_scenarios() {
  TEST_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  TEST_START_EPOCH=$(date -u +%s)
  run_and_capture_scenario 0
  run_and_capture_scenario 1
  run_and_capture_scenario 2
  run_and_capture_scenario 3
  run_and_capture_scenario 4
  run_and_capture_scenario 5
  run_and_capture_scenario 6
  run_and_capture_scenario 7
  run_and_capture_scenario 8
  run_and_capture_scenario 9
}

# ─── Write Markdown report ────────────────────────────────────────────────────
write_report() {
  echo ">>> Writing report to $REPORT_FILE"

  # Checklist state from global scenario result arrays
  local s0_ok s1_ok s2_ok s3_ok s4_ok s5_ok s6_ok s7_ok s8_ok s9_ok logs_ok metrics_ok status_ok
  all_equal "200" "${S0_RESULTS[@]}" && s0_ok="true" || s0_ok="false"
  all_equal "401" "${S1_RESULTS[@]}" && s1_ok="true" || s1_ok="false"

  # Tyk returns 403 (not 401) for an unrecognized key — both are auth failure
  local s2_fail=true
  for v in "${S2_RESULTS[@]}"; do [[ "$v" != "401" && "$v" != "403" ]] && s2_fail=false && break; done
  [[ "$s2_fail" == "true" ]] && s2_ok="true" || s2_ok="false"

  # Tyk returns 403 for quota exceeded (not 429 — that's rate limit)
  local s3_200 s3_403
  s3_200=$(count_value "200" "${S3_RESULTS[@]}")
  s3_403=$(count_value "403" "${S3_RESULTS[@]}")
  [[ "$s3_200" -ge 28 && "$s3_403" -ge 1 ]] && s3_ok="true" || s3_ok="false"

  contains_429 "${S4_RESULTS[@]}" && s4_ok="true" || s4_ok="false"

  local s5_200 s5_errors s9_200
  s5_200=$(count_value "200" "${S5_RESULTS[@]}")
  s5_errors=$((20 - s5_200))
  [[ "$s5_errors" -ge 15 ]] && s5_ok="true" || s5_ok="false"
  all_equal "200" "${S6_RESULTS[@]}" && s6_ok="true" || s6_ok="false"
  all_equal "500" "${S7_RESULTS[@]}" && s7_ok="true" || s7_ok="false"
  all_equal "200" "${S8_RESULTS[@]}" && s8_ok="true" || s8_ok="false"
  s9_200=$(count_value "200" "${S9_RESULTS[@]}")
  [[ "$s9_200" -ge 5 ]] && s9_ok="true" || s9_ok="false"

  [[ "$TOTAL_LOG_LINES" -gt 0 ]] && logs_ok="true" || logs_ok="false"
  [[ "$METRICS_OK" == "true" ]] && metrics_ok="true" || metrics_ok="false"
  [[ "$STATUS_OK" == "true" ]] && status_ok="true" || status_ok="false"

  # Custom metrics configured in .env
  local custom_metrics_list
  custom_metrics_list=$(python3 -c "
import json, re
try:
    with open('.env') as f:
        content = f.read()
    m = re.search(r'TYK_GW_OPENTELEMETRY_METRICS_APIMETRICS=(.+)', content)
    if m:
        arr = json.loads(m.group(1))
        for metric in arr:
            print(f\"- \`{metric['name']}\` ({metric['type']}): {metric.get('description','')}\")
    else:
        print('_(TYK_GW_OPENTELEMETRY_METRICS_APIMETRICS not found in .env)_')
except Exception as e:
    print(f'_(could not parse .env: {e})_')
" 2>/dev/null || echo "_(could not read .env)_")

  # Write report: header + per-scenario sections + footer
  {
    cat <<HEADER
# Tyk Gateway Signals Report

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Gateway URL:** $GATEWAY_URL
**Test API:** Report Test API (\`$TEST_API_ID\`)
**Test window:** $TEST_START → $(date -u +"%Y-%m-%dT%H:%M:%SZ")

---

## Test Setup

### API Definition

| Field | Value |
|-------|-------|
| Name | Report Test API |
| Listen path | \`$TEST_API_PATH/\` |
| Target | \`http://httpbin.org/\` |
| Auth | Bearer token (\`x-api-key\` header) |
| Detailed recording | enabled |

### Policies

| Policy | ID | Quota (max/renewal) | Rate |
|--------|----|---------------------|------|
| Report Low Policy | \`$POL_LOW\` | 30 / 3600s | 100 req/s |
| Report Mid Policy | \`$POL_MID\` | 1000 / 3600s | 10 req/s |
| Report Slow Policy | \`$POL_SLOW\` | 100 / 3600s | 50 req/s |

### Keys

| Key | Policy | Quota |
|-----|--------|-------|
| \`$KEY_LOW\` | Report Low Policy | 30 |
| \`$KEY_MID\` | Report Mid Policy | 1000 |
| \`$KEY_SLOW\` | Report Slow Policy | 100 |

### Configured Custom Metrics (\`.env\`)

$custom_metrics_list

---

HEADER

    for n in 0 1 2 3 4 5 6 7 8 9; do
      cat "/tmp/report_section_${n}_${TIMESTAMP}.md"
    done

    cat <<FOOTER
## Verification Checklist

- [$(check_mark "$s0_ok")] S0: All 5 valid requests returned 200
- [$(check_mark "$s1_ok")] S1: All 5 missing-auth requests returned 401
- [$(check_mark "$s2_ok")] S2: All 5 invalid-key requests returned 401 or 403
- [$(check_mark "$s3_ok")] S3: Quota exhaustion — ${s3_200}× 200, ${s3_403}× 403 (Tyk quota exceeded = 403; expected ≥28× 200, ≥1× 403)
- [$(check_mark "$s4_ok")] S4: Rate limit burst produced at least one 429
- [$(check_mark "$s5_ok")] S5 R01: High error rate — ${s5_errors} non-200 of 20 (expected ≥15)
- [$(check_mark "$s6_ok")] S6 R02: Latency spike — all 5 returned 200 (upstream latency in signals)
- [$(check_mark "$s7_ok")] S7 R06: Upstream 5xx — all 10 returned 500
- [$(check_mark "$s8_ok")] S8 R07: Tenant anomaly — all 10 returned 200 (compare latency per key)
- [$(check_mark "$s9_ok")] S9 R08: Runtime load — ${s9_200} of 50 returned 200 (429s expected)
- [$(check_mark "$logs_ok")] Gateway logs contain access-log entries
- [$(check_mark "$metrics_ok")] At least one metric changed (delta > 0)
- [$(check_mark "$status_ok")] Metrics include 401 or 429 status code labels
FOOTER
  } > "$REPORT_FILE"

  echo "    Report written: $REPORT_FILE"
}

# ─── Cleanup temp files ───────────────────────────────────────────────────────
cleanup_tmp() {
  rm -f "/tmp/report_section_"[0-9]"_${TIMESTAMP}.md"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  check_prereqs
  get_credentials
  cleanup_stale
  create_test_api
  create_policies
  create_keys
  run_all_scenarios
  write_report
  cleanup_tmp

  echo ""
  echo "========================================================"
  echo "Gateway Signals Report complete!"
  echo "  Report: $REPORT_FILE"
  echo ""
  echo "Re-run anytime: bash deployments/opentelemetry-demo/scripts/gateway-signals-report.sh"
  echo "========================================================"
}

main "$@"
