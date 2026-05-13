#!/usr/bin/env bash
# path-signals-report.sh
#
# Tests how Tyk Gateway records path-related telemetry across three signals:
#   - Prometheus metrics  (which label dimensions include the request path)
#   - Gateway access logs (path fields: listen path, upstream path, api_path, etc.)
#   - Jaeger traces       (span attributes: http.url, http.target, http.route, url.path)
#
# Usage: bash deployments/opentelemetry-demo/scripts/path-signals-report.sh
#
# Prerequisites:
#   - tyk-demo stack and opentelemetry-demo running: ./up.sh opentelemetry-demo
#   - docker, curl, python3 available
# The httpbun container and the httpbun-test API are created automatically if missing.
# Re-runnable: safe to run multiple times.

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
DASHBOARD_URL="http://localhost:3000"
GATEWAY_URL="http://localhost:8080"
GATEWAY_SECRET="28d220fd77974a4facfb07dc1e49c2aa"
PROMETHEUS_API="http://localhost:9090"
JAEGER_URL="http://localhost:8085/jaeger/ui/api/traces"
GW_CONTAINER="tyk-demo-tyk-gateway-1"

TEST_API_PATH="/httpbun-test"
HTTPBUN_DIRECT="http://localhost:8099"
HTTPBUN_CONTAINER="httpbun"
HTTPBUN_IMAGE="sharat87/httpbun"
HTTPBUN_PORT="8099"
HTTPBUN_NETWORK="tyk-demo_tyk"
HTTPBUN_PATH_PREFIX="test1"
HTTPBUN_UPSTREAM_URL="http://httpbun:80/${HTTPBUN_PATH_PREFIX}"
BOOTSTRAP_LOG="logs/bootstrap.log"
REPORTS_DIR="reports"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_FILE="${REPORTS_DIR}/path-signals-report-${TIMESTAMP}.md"
ANALYTICS_WAIT_SECS=20  # time to wait after last scenario for analytics flush (gateway ~10s + pump 2s)

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
  start_httpbun
  mkdir -p "$REPORTS_DIR"
  echo "    OK"
}

# ─── Start httpbun ────────────────────────────────────────────────────────────
_httpbun_run() {
  docker run -d \
    --name "$HTTPBUN_CONTAINER" \
    --network "$HTTPBUN_NETWORK" \
    -p "${HTTPBUN_PORT}:80" \
    "$HTTPBUN_IMAGE" --path-prefix "$HTTPBUN_PATH_PREFIX"
  # Give it a moment then verify it didn't immediately crash
  sleep 1
  local post_state
  post_state=$(docker inspect --format '{{.State.Status}}' "$HTTPBUN_CONTAINER" 2>/dev/null | tr -d '[:space:]') || true
  if [[ "$post_state" != "running" ]]; then
    echo "ERROR: httpbun container exited immediately (state=$post_state). Logs:" >&2
    docker logs "$HTTPBUN_CONTAINER" 2>&1 >&2
    exit 1
  fi
}

start_httpbun() {
  echo ">>> Starting httpbun"

  local state
  state=$(docker inspect --format '{{.State.Status}}' "$HTTPBUN_CONTAINER" 2>/dev/null | tr -d '[:space:]') || true
  if [[ -z "$state" ]]; then state="missing"; fi

  case "$state" in
    running)
      echo "    Already running — skipping"
      ;;
    exited|created|paused)
      echo "    Container exists but is $state — restarting"
      if ! docker start "$HTTPBUN_CONTAINER" 2>&1; then
        echo "    docker start failed (stale network?) — removing and recreating"
        docker rm "$HTTPBUN_CONTAINER" >/dev/null
        _httpbun_run
      fi
      ;;
    missing)
      echo "    Pulling $HTTPBUN_IMAGE and starting container (--path-prefix $HTTPBUN_PATH_PREFIX)"
      _httpbun_run
      ;;
    *)
      echo "    Unknown container state '$state' — attempting docker start"
      if ! docker start "$HTTPBUN_CONTAINER" 2>&1; then
        echo "    docker start failed — removing and recreating"
        docker rm "$HTTPBUN_CONTAINER" >/dev/null
        _httpbun_run
      fi
      ;;
  esac

  # Wait up to 15s for httpbun to respond, then show logs on failure
  local attempts=0
  until curl -sf "$HTTPBUN_DIRECT/${HTTPBUN_PATH_PREFIX}/get" >/dev/null 2>&1; do
    attempts=$(( attempts + 1 ))
    if [[ "$attempts" -ge 15 ]]; then
      echo "ERROR: httpbun did not become ready after ${attempts}s. Container logs:" >&2
      docker logs "$HTTPBUN_CONTAINER" 2>&1 | tail -20 >&2
      exit 1
    fi
    sleep 1
  done
  echo "    httpbun ready at $HTTPBUN_DIRECT/${HTTPBUN_PATH_PREFIX}"
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

# ─── Resolve or create API ────────────────────────────────────────────────────
resolve_api_id() {
  echo ">>> Resolving API ID for listen path $TEST_API_PATH"

  # Search classic APIs
  TEST_API_ID=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis?p=-1" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
apis = data.get('apis', [])
matches = [a['api_definition']['api_id'] for a in apis
           if a['api_definition'].get('proxy',{}).get('listen_path','').rstrip('/') == '$TEST_API_PATH']
print(matches[0] if matches else '', end='')
" 2>/dev/null || echo "")

  # Search OAS APIs if not found in classic
  if [[ -z "$TEST_API_ID" ]]; then
    TEST_API_ID=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis/oas?p=-1" | \
      python3 -c "
import sys, json
data = json.load(sys.stdin)
apis = data.get('apis', [])
matches = [a.get('x-tyk-api-gateway',{}).get('info',{}).get('id','') for a in apis
           if a.get('x-tyk-api-gateway',{}).get('server',{}).get('listenPath',{}).get('value','').rstrip('/') == '$TEST_API_PATH']
print(matches[0] if matches else '', end='')
" 2>/dev/null || echo "")
  fi

  if [[ -n "$TEST_API_ID" ]]; then
    echo "    API ID: $TEST_API_ID — ensuring upstream URL is $HTTPBUN_UPSTREAM_URL"
    update_api_upstream_url "$TEST_API_ID"
    ensure_api_auth_and_key
    return
  fi

  echo "    API not found — creating it"
  create_httpbun_api
  ensure_api_auth_and_key
}

update_api_upstream_url() {
  local api_id="$1"
  # Fetch the current OAS definition, patch the upstream URL, PUT it back
  local current_def
  current_def=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis/oas/$api_id" 2>/dev/null || echo "")
  if [[ -z "$current_def" ]]; then
    echo "    WARN: could not fetch OAS definition for $api_id — skipping upstream update" >&2
    return
  fi

  local current_url
  current_url=$(echo "$current_def" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('x-tyk-api-gateway', {}).get('upstream', {}).get('url', ''), end='')
" 2>/dev/null || echo "")

  if [[ "$current_url" == "$HTTPBUN_UPSTREAM_URL" ]]; then
    echo "    Upstream URL already set to $HTTPBUN_UPSTREAM_URL — no update needed"
    return
  fi

  echo "    Updating upstream URL: $current_url → $HTTPBUN_UPSTREAM_URL"
  local updated_def
  updated_def=$(echo "$current_def" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d.setdefault('x-tyk-api-gateway', {}).setdefault('upstream', {})['url'] = sys.argv[1]
print(json.dumps(d))
" "$HTTPBUN_UPSTREAM_URL")

  curl -sf -X PUT "$DASHBOARD_URL/api/apis/oas/$api_id" \
    -H "Authorization: $USER_KEY" \
    -H "Content-Type: application/json" \
    -d "$updated_def" >/dev/null

  echo "    Hot reloading gateway"
  curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
    -H "x-tyk-authorization: $GATEWAY_SECRET" >/dev/null
  sleep 2
}

create_httpbun_api() {
  local api_def
  api_def=$(python3 -c "
import json, sys

org_id = sys.argv[1]
upstream_url = sys.argv[2]
d = {
  'info': {'title': 'httpbun-test', 'version': '1.0.0'},
  'openapi': '3.0.3',
  'servers': [{'url': '/httpbun-test'}],
  'security': [{'authToken': []}],
  'paths': {
    '/anything/{path}': {
      'get': {
        'operationId': 'anything/{path}get',
        'parameters': [{'in': 'path', 'name': 'path', 'required': True, 'schema': {'type': 'string'}}],
        'responses': {'200': {'description': ''}}
      },
      'parameters': [{'in': 'path', 'name': 'path', 'required': True, 'schema': {'type': 'string'}}]
    }
  },
  'components': {
    'securitySchemes': {
      'authToken': {'type': 'apiKey', 'in': 'header', 'name': 'Authorization'}
    }
  },
  'x-tyk-api-gateway': {
    'info': {
      'orgId': org_id,
      'name': 'httpbun-test',
      'state': {'active': True, 'internal': False}
    },
    'upstream': {
      'proxy': {'enabled': False, 'url': ''},
      'url': upstream_url
    },
    'server': {
      'authentication': {
        'enabled': True,
        'securitySchemes': {'authToken': {'enabled': True}}
      },
      'listenPath': {'value': '/httpbun-test/', 'strip': True}
    },
    'middleware': {
      'global': {
        'contextVariables': {'enabled': True},
        'trafficLogs': {'enabled': True}
      },
      'operations': {
        'anything/{path}get': {
          'trackEndpoint': {'enabled': True}
        }
      }
    }
  }
}
print(json.dumps(d))
" "$ORG_ID" "$HTTPBUN_UPSTREAM_URL")

  local create_resp
  create_resp=$(curl -sf -X POST "$DASHBOARD_URL/api/apis/oas" \
    -H "Authorization: $USER_KEY" \
    -H "Content-Type: application/json" \
    -d "$api_def")

  TEST_API_ID=$(echo "$create_resp" | python3 -c "
import sys, json
d = json.load(sys.stdin)
# Dashboard returns the OAS doc or a wrapper; extract the tyk api id
print(d.get('x-tyk-api-gateway', {}).get('info', {}).get('id', '')
      or d.get('Meta', '') or d.get('APIID', ''), end='')
" 2>/dev/null || echo "")

  if [[ -z "$TEST_API_ID" ]]; then
    echo "ERROR: API creation failed. Response: $create_resp" >&2
    exit 1
  fi

  echo "    Created API ID: $TEST_API_ID — hot reloading gateway"
  curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
    -H "x-tyk-authorization: $GATEWAY_SECRET" >/dev/null
  sleep 2
}

# ─── Auth + test key ─────────────────────────────────────────────────────────
ensure_api_auth_and_key() {
  echo ">>> Ensuring API has token auth and creating test key"

  local current_def
  current_def=$(curl -sf -H "Authorization: $USER_KEY" "$DASHBOARD_URL/api/apis/oas/$TEST_API_ID" 2>/dev/null) || current_def=""
  if [[ -z "$current_def" ]]; then
    echo "    WARN: could not fetch OAS definition for $TEST_API_ID — skipping auth setup" >&2
    return
  fi

  local auth_enabled
  auth_enabled=$(echo "$current_def" | python3 -c "
import sys, json
d = json.load(sys.stdin)
auth = d.get('x-tyk-api-gateway', {}).get('server', {}).get('authentication', {})
print('true' if auth.get('enabled') else 'false', end='')
" 2>/dev/null) || auth_enabled="false"

  if [[ "$auth_enabled" != "true" ]]; then
    echo "    Auth not enabled — enabling token auth on the API"
    local updated_def
    updated_def=$(echo "$current_def" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d.setdefault('components', {}).setdefault('securitySchemes', {})['authToken'] = {
    'type': 'apiKey', 'in': 'header', 'name': 'Authorization'}
d['security'] = [{'authToken': []}]
gw = d.setdefault('x-tyk-api-gateway', {})
gw.setdefault('server', {}).setdefault('authentication', {})['enabled'] = True
gw['server']['authentication'].setdefault('securitySchemes', {})['authToken'] = {'enabled': True}
print(json.dumps(d))
" 2>/dev/null)

    curl -sf -X PUT "$DASHBOARD_URL/api/apis/oas/$TEST_API_ID" \
      -H "Authorization: $USER_KEY" \
      -H "Content-Type: application/json" \
      -d "$updated_def" >/dev/null

    echo "    Hot reloading gateway (auth change)"
    curl -sf "$GATEWAY_URL/tyk/reload/group?block=true" \
      -H "x-tyk-authorization: $GATEWAY_SECRET" >/dev/null
    sleep 2
  else
    echo "    Auth already enabled"
  fi

  # Create a fresh test key for this run (deleted at cleanup)
  local key_body
  key_body=$(python3 -c "
import json, sys
print(json.dumps({
    'access_rights': {
        '$TEST_API_ID': {
            'api_id': '$TEST_API_ID',
            'api_name': 'httpbun-test',
            'versions': ['Default']
        }
    },
    'org_id': '$ORG_ID',
    'expires': 0,
    'quota_max': -1,
    'rate': -1,
    'per': 0
}))
")

  local key_resp
  key_resp=$(curl -sf -X POST "$DASHBOARD_URL/api/keys" \
    -H "Authorization: $USER_KEY" \
    -H "Content-Type: application/json" \
    -d "$key_body" 2>/dev/null) || key_resp=""

  TEST_KEY=$(echo "$key_resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('key_id') or d.get('key',''), end='')" 2>/dev/null) || TEST_KEY=""
  TEST_KEY_HASH=$(echo "$key_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('key_hash',''), end='')" 2>/dev/null) || TEST_KEY_HASH=""

  if [[ -z "$TEST_KEY" ]]; then
    echo "ERROR: Failed to create test key. Response: $key_resp" >&2
    exit 1
  fi
  echo "    Test key: ${TEST_KEY:0:12}...  hash: ${TEST_KEY_HASH:0:12}..."
}

# ─── Prometheus snapshot ──────────────────────────────────────────────────────
snapshot_prometheus() {
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

json_file     = sys.argv[1]
outfile       = sys.argv[2]
api_id_filter = sys.argv[3] if len(sys.argv) > 3 else ''
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

# ─── Extract path-related fields from access logs ────────────────────────────
extract_path_fields() {
  # Reads a filtered access-log file and returns a table of path-related fields
  local logfile="$1"
  python3 -c "
import sys, json

PATH_FIELDS = [
    'path', 'api_path', 'request_uri', 'url_path', 'base_path',
    'listen_path', 'upstream_address', 'key_id', 'response_code',
]

logfile = sys.argv[1]
rows = []
try:
    with open(logfile) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                if d.get('prefix') != 'access-log':
                    continue
                row = {k: str(d.get(k, '')) for k in PATH_FIELDS if k in d or d.get(k) is not None}
                # Also collect any other keys that contain 'path' or 'url'
                for k, v in d.items():
                    if ('path' in k.lower() or 'url' in k.lower() or 'uri' in k.lower()) and k not in row:
                        row[k] = str(v)
                rows.append(row)
            except Exception:
                pass
except FileNotFoundError:
    pass

if not rows:
    print('_No access-log entries found._')
    sys.exit(0)

# Collect all field names seen
all_fields = []
seen = set()
for preferred in PATH_FIELDS:
    if any(preferred in r for r in rows):
        all_fields.append(preferred)
        seen.add(preferred)
for r in rows:
    for k in sorted(r.keys()):
        if k not in seen:
            all_fields.append(k)
            seen.add(k)

# Print as markdown table
header = '| # | ' + ' | '.join(all_fields) + ' |'
sep    = '|---|' + '|'.join(['---'] * len(all_fields)) + '|'
print(header)
print(sep)
for i, r in enumerate(rows, 1):
    vals = [r.get(f, '') for f in all_fields]
    print('| ' + str(i) + ' | ' + ' | '.join(f'\`{v}\`' if v else '' for v in vals) + ' |')
" "$logfile"
}

# ─── Extract path-related span attributes from Jaeger ────────────────────────
query_jaeger_path_attrs() {
  local start_us="$1"
  local end_us="$2"
  local jaeger_tmp="$3"

  curl -sf "${JAEGER_URL}?service=tyk-gateway&start=${start_us}&end=${end_us}&limit=200" \
    -o "$jaeger_tmp" 2>/dev/null || echo '{"data":[]}' > "$jaeger_tmp"

  python3 -c "
import json, sys

PATH_SPAN_ATTRS = [
    'http.url', 'http.target', 'http.route', 'http.method', 'http.status_code',
    'url.path', 'url.full', 'url.query', 'net.peer.name', 'net.peer.port',
    'tyk.api_id', 'tyk.api_path', 'tyk.listen_path',
]

with open(sys.argv[1]) as f:
    d = json.load(f)

data = d.get('data', [])
if not data:
    print('_No traces found._')
    sys.exit(0)

rows = []
for trace in data:
    tid = trace.get('traceID','')[:8]
    for span in trace.get('spans', []):
        op = span.get('operationName', '')
        dur = f\"{span.get('duration', 0) / 1000:.1f}ms\"
        span_tags = {t['key']: str(t.get('value', '')) for t in span.get('tags', [])}

        # Collect path-related attributes
        path_attrs = {k: v for k, v in span_tags.items()
                      if k in PATH_SPAN_ATTRS
                      or 'path' in k.lower() or 'url' in k.lower()
                      or 'route' in k.lower() or 'uri' in k.lower()
                      or k.startswith('tyk.')}
        if path_attrs:
            rows.append((tid, op, dur, path_attrs))

if not rows:
    print('_No spans with path-related attributes found._')
    sys.exit(0)

# Collect all attribute keys seen
all_attr_keys = []
seen = set()
for preferred in PATH_SPAN_ATTRS:
    if any(preferred in r[3] for r in rows):
        all_attr_keys.append(preferred)
        seen.add(preferred)
for _, _, _, attrs in rows:
    for k in sorted(attrs.keys()):
        if k not in seen:
            all_attr_keys.append(k)
            seen.add(k)

header = '| TraceID | Operation | Duration | ' + ' | '.join(all_attr_keys) + ' |'
sep    = '|---------|-----------|----------|' + '|'.join(['---'] * len(all_attr_keys)) + '|'
print(header)
print(sep)
for tid, op, dur, attrs in rows[:100]:
    vals = [attrs.get(k, '') for k in all_attr_keys]
    print('| \`' + tid + '\` | ' + op + ' | ' + dur + ' | ' + ' | '.join(f'\`{v}\`' if v else '' for v in vals) + ' |')

print()
print(f'**Total spans with path attributes:** {len(rows)}' + (' (showing first 100)' if len(rows) > 100 else ''))
" "$jaeger_tmp"
}

# ─── Query Tyk Analytics DB ──────────────────────────────────────────────────
# Queries the selective MongoDB collection (z_tyk_analyticz_<orgid>) directly.
#   path    = normalized/templated path (e.g. /test1/status/{id})
#   rawpath = actual request path       (e.g. /test1/status/404)
# Both fields reveal what Tyk stores in its analytics DB, distinct from OTLP signals.
query_tyk_analytics() {
  local start_epoch="$1"
  local end_epoch="$2"

  # Auto-detect MongoDB container
  local mongo_container
  mongo_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i 'mongo' | head -1) || mongo_container=""
  if [[ -z "$mongo_container" ]]; then
    echo "_Analytics unavailable: no MongoDB container found._"
    return
  fi

  # Convert epochs to ISO strings for MongoDB query
  local start_iso end_iso
  start_iso=$(python3 -c "import datetime; print(datetime.datetime.utcfromtimestamp($start_epoch).strftime('%Y-%m-%dT%H:%M:%S.000Z'))")
  end_iso=$(python3 -c "import datetime; print(datetime.datetime.utcfromtimestamp($end_epoch).strftime('%Y-%m-%dT%H:%M:%S.000Z'))")
  echo "    MongoDB: $mongo_container | window: $start_iso → $end_iso"

  # Discover org-specific selective collection name
  local org_suffix
  org_suffix=$(docker exec "$mongo_container" mongosh tyk_analytics --quiet --eval \
    "db.getCollectionNames().filter(n => n.match(/^z_tyk_analyticz_[^a]/)).map(n => n.replace('z_tyk_analyticz_',''))[0]" \
    2>/dev/null | tr -d '[:space:]') || org_suffix=""

  if [[ -z "$org_suffix" ]]; then
    echo "_Analytics unavailable: could not find selective analytics collection._"
    return
  fi

  local collection="z_tyk_analyticz_${org_suffix}"
  echo "    Collection: $collection"

  # Query records for our API in the time window
  local raw_json
  raw_json=$(docker exec "$mongo_container" mongosh tyk_analytics --quiet --eval "
var col = db['$collection'];
var docs = col.find({
  apiid: '$TEST_API_ID',
  timestamp: {\$gte: new Date('$start_iso'), \$lte: new Date('$end_iso')}
}, {path:1, rawpath:1, responsecode:1, requesttime:1, _id:0}).toArray();
print(JSON.stringify(docs));
" 2>/dev/null) || raw_json="[]"

  echo "$raw_json" | python3 -c "
import sys, json
from collections import defaultdict

def to_num(v):
    # mongosh serialises BSON Int64 as {'\$numberLong':'123'}, Int32 as {'\$numberInt':'123'}
    if isinstance(v, dict):
        return float(v.get('\$numberLong', v.get('\$numberInt', v.get('\$numberDouble', 0))))
    return float(v) if v is not None else 0.0

try:
    docs = json.loads(sys.stdin.read())
except Exception as e:
    print(f'_Analytics parse error: {e}_')
    sys.exit(0)

if not docs:
    print('_No analytics records found for this time window._')
    sys.exit(0)

# Group by (path, rawpath, responsecode)
groups = defaultdict(lambda: {'hits': 0, 'total_rt': 0.0})
for d in docs:
    key = (d.get('path',''), d.get('rawpath',''), int(to_num(d.get('responsecode', 0))))
    groups[key]['hits'] += 1
    groups[key]['total_rt'] += to_num(d.get('requesttime', 0))

rows = sorted(groups.items(), key=lambda x: (x[0][0], x[0][2]))

print('| Normalized Path | Raw Path | Code | Hits | Avg Req Time (ms) |')
print('|-----------------|----------|------|------|-------------------|')
for (path, rawpath, code), stats in rows:
    hits   = stats['hits']
    avg_rt = f\"{(stats['total_rt'] / hits):.1f}\" if hits else '0.0'
    flag   = ' ⚑' if path != rawpath else ''
    print(f'| \`{path}{flag}\` | \`{rawpath}\` | {code} | {hits} | {avg_rt} |')

print()
print(f'**Total records:** {len(docs)} requests grouped into {len(rows)} path×code combinations.')
print('> ⚑ = Tyk normalized the raw path to a template (e.g. \`/test1/status/404\` → \`/test1/status/{id}\`).')
print('> **Key observation:** do the paths include the \`test1\` upstream prefix, or the gateway listen path prefix?')
"
}

# ─── Run a scenario ───────────────────────────────────────────────────────────
run_scenario() {
  local n="$1"

  local tmp_before="/tmp/path_s${n}_before_${TIMESTAMP}.txt"
  local tmp_after="/tmp/path_s${n}_after_${TIMESTAMP}.txt"
  local tmp_logs="/tmp/path_s${n}_logs_${TIMESTAMP}.txt"
  local tmp_filtered="/tmp/path_s${n}_filtered_${TIMESTAMP}.txt"
  local tmp_jaeger="/tmp/path_s${n}_jaeger_${TIMESTAMP}.json"
  local section_file="/tmp/path_section_${n}_${TIMESTAMP}.md"

  local s_name s_desc
  case "$n" in
    0) s_name="P0: Baseline — /get"
       s_desc="5× GET \`$GATEWAY_URL$TEST_API_PATH/get\` → upstream \`$HTTPBUN_UPSTREAM_URL/get\`. Establishes baseline. Checks: how the literal path \`/get\` appears in each signal." ;;
    1) s_name="P1: Variable path segments — /anything/foo vs /anything/bar"
       s_desc="5× \`$GATEWAY_URL$TEST_API_PATH/anything/foo\` + 5× \`$GATEWAY_URL$TEST_API_PATH/anything/bar\` → upstream \`$HTTPBUN_UPSTREAM_URL/anything/{val}\`. Checks: are different values of the same path template collapsed in metrics labels, or recorded verbatim?" ;;
    2) s_name="P2: Status-via-path — /status/200 vs /status/404"
       s_desc="5× \`$GATEWAY_URL$TEST_API_PATH/status/200\` + 5× \`$GATEWAY_URL$TEST_API_PATH/status/404\` → upstream \`$HTTPBUN_UPSTREAM_URL/status/{code}\`. Checks: same path template, different status codes — how do metrics labels split this?" ;;
    3) s_name="P3: Breadth — multiple distinct paths"
       s_desc="1× each of \`$TEST_API_PATH/get\`, \`$TEST_API_PATH/headers\`, \`$TEST_API_PATH/anything/test\`, \`$TEST_API_PATH/ip\`, \`$TEST_API_PATH/uuid\` via \`$GATEWAY_URL\` → upstream \`$HTTPBUN_UPSTREAM_URL/{path}\`. Wide variety in one window to compare path recording in traces." ;;
  esac

  echo ""
  echo "========================================================"
  echo ">>> $s_name"
  echo "========================================================"

  # (1) Prometheus before
  snapshot_prometheus "$tmp_before" "$TEST_API_ID"
  local s_start s_start_epoch
  s_start=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  s_start_epoch=$(date -u +%s)

  # (2) Run traffic
  RESULTS=()
  case "$n" in
    0)
      echo "  Sending 5x GET /get"
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: $TEST_KEY" "$GATEWAY_URL$TEST_API_PATH/get")
        RESULTS+=("GET /get → $STATUS")
        printf "  [%02d] GET /get → %s\n" "$i" "$STATUS"
        sleep 0.3
      done
      ;;
    1)
      echo "  Sending 5x /anything/foo then 5x /anything/bar"
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: $TEST_KEY" "$GATEWAY_URL$TEST_API_PATH/anything/foo")
        RESULTS+=("GET /anything/foo → $STATUS")
        printf "  [%02d] GET /anything/foo → %s\n" "$i" "$STATUS"
        sleep 0.3
      done
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: $TEST_KEY" "$GATEWAY_URL$TEST_API_PATH/anything/bar")
        RESULTS+=("GET /anything/bar → $STATUS")
        printf "  [%02d] GET /anything/bar → %s\n" "$i" "$STATUS"
        sleep 0.3
      done
      ;;
    2)
      echo "  Sending 5x /status/200 then 5x /status/404"
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: $TEST_KEY" "$GATEWAY_URL$TEST_API_PATH/status/200")
        RESULTS+=("GET /status/200 → $STATUS")
        printf "  [%02d] GET /status/200 → %s\n" "$i" "$STATUS"
        sleep 0.3
      done
      for i in $(seq 1 5); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: $TEST_KEY" "$GATEWAY_URL$TEST_API_PATH/status/404")
        RESULTS+=("GET /status/404 → $STATUS")
        printf "  [%02d] GET /status/404 → %s\n" "$i" "$STATUS"
        sleep 0.3
      done
      ;;
    3)
      for path in /get /headers /anything/test /ip /uuid; do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: $TEST_KEY" "$GATEWAY_URL$TEST_API_PATH$path")
        RESULTS+=("GET $path → $STATUS")
        printf "  GET %s → %s\n" "$path" "$STATUS"
        sleep 0.3
      done
      ;;
  esac

  # (3) Wait for OTLP export flush
  echo "    Waiting 10s for OTLP export..."
  sleep 10
  local s_end_epoch
  s_end_epoch=$(date -u +%s)

  # (4) Prometheus after + delta
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

  # (5) Gateway access logs
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

  local log_path_table
  log_path_table=$(extract_path_fields "$tmp_filtered")

  local raw_logs
  if [[ "$n_log_lines" -gt 0 ]]; then
    raw_logs=$(cat "$tmp_filtered")
  else
    raw_logs="_(No access-log entries for this scenario.)_"
  fi

  # (6) Jaeger traces
  local start_us end_us jaeger_table
  start_us="${s_start_epoch}000000"
  end_us="${s_end_epoch}000000"
  jaeger_table=$(query_jaeger_path_attrs "$start_us" "$end_us" "$tmp_jaeger" 2>/dev/null \
    || echo "_Jaeger unavailable_")
  rm -f "$tmp_jaeger"

  # (7) Build results list
  local results_md
  results_md=$(printf '%s\n' "${RESULTS[@]}" | sed 's/^/- /')

  # (8) Write section
  cat > "$section_file" <<SECTION
## $s_name

$s_desc

### Requests sent

$results_md

### Access Log — Path Fields

Filtered from \`docker logs $GW_CONTAINER --since $s_start\` (access-log entries for API \`$TEST_API_ID\` only).
$n_log_lines entries captured.

$log_path_table

<details>
<summary>Raw access-log JSON</summary>

\`\`\`
$raw_logs
\`\`\`

</details>

### Prometheus Metrics Delta

Source: \`${PROMETHEUS_API}/api/v1/query\` filtered to API \`$TEST_API_ID\` — non-zero delta only.
Look for label dimensions like \`tyk_api_path\`, \`http_target\`, \`url_path\`, \`endpoint\`, etc.

$delta_table

### Jaeger Traces — Path-Related Span Attributes

Service: \`tyk-gateway\` | Window: $s_start → $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Columns show only path-related attributes (http.url, http.target, http.route, url.path, tyk.* etc.)

$jaeger_table

---
SECTION

  echo "    Logs: $n_log_lines access-log entries"
  echo "    Metrics: $(echo "$delta_output" | grep -c . || true) series changed"

  # Cleanup
  rm -f "$tmp_before" "$tmp_after" "$tmp_logs" "$tmp_filtered"
}

# ─── Path label matrix ────────────────────────────────────────────────────────
# Summarises the path representation across signals, built from section files
build_path_matrix() {
  echo "## Path Representation Matrix"
  echo ""
  echo "How the request path appears in each telemetry signal:"
  echo ""
  echo "| Signal | Field / Label | Example values seen |"
  echo "|--------|---------------|---------------------|"
  echo "| **Prometheus** | label dimensions on \`tyk_http_*\` metrics | See delta tables in each scenario |"
  echo "| **Access log** | JSON fields (path, api_path, url_path, …) | See path field tables in each scenario |"
  echo "| **Jaeger span** | \`http.target\`, \`http.url\`, \`http.route\`, \`url.path\` | See span attribute tables in each scenario |"
  echo "| **Analytics DB** | \`id.path\` in MongoDB aggregate records | See Tyk Analytics DB section |"
  echo ""
  echo "> **What to look for:**"
  echo "> - Are variable path segments (\`/anything/foo\` vs \`/anything/bar\`) recorded verbatim or normalised to a template?"
  echo "> - Does the metrics label carry the listen-path prefix (\`/httpbun-test/get\`) or just the upstream path (\`/get\`)?"
  echo "> - Does the trace attribute match the access-log field for the same request?"
  echo ""
}

# ─── Write report ─────────────────────────────────────────────────────────────
write_report() {
  echo ">>> Writing report to $REPORT_FILE"
  {
    cat <<HEADER
# Tyk Gateway Path Signals Report

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Gateway URL:** $GATEWAY_URL
**Test API:** Httpbun Path Test (\`$TEST_API_ID\`)
**Upstream:** httpbun (\`$HTTPBUN_UPSTREAM_URL\`)
**Listen path:** \`$TEST_API_PATH/\`
**Test window:** $TEST_START → $(date -u +"%Y-%m-%dT%H:%M:%SZ")

---

## Test Setup

| Field | Value |
|-------|-------|
| Name | Httpbun Path Test |
| Listen path | \`$TEST_API_PATH/\` |
| Target | \`$HTTPBUN_UPSTREAM_URL\` |
| Strip listen path | enabled |
| Auth | Token (test key \`${TEST_KEY:0:12}...\`) |
| Detailed recording | enabled |

---

$(build_path_matrix)

---

HEADER

    for n in 0 1 2 3; do
      cat "/tmp/path_section_${n}_${TIMESTAMP}.md"
    done

    cat "/tmp/path_analytics_${TIMESTAMP}.md" 2>/dev/null || true

    cat <<FOOTER
## Checklist

- [ ] P0: Gateway path \`$TEST_API_PATH/get\` → upstream \`/test1/get\` visible in access log \`path\` / \`api_path\` fields
- [ ] P0: Path appears in Prometheus metric label (gateway or upstream form?)
- [ ] P0: \`http.target\` or \`http.route\` in Jaeger span — does it show the gateway path (\`$TEST_API_PATH/get\`) or the upstream path (\`/test1/get\`)?
- [ ] P1: Are \`$TEST_API_PATH/anything/foo\` and \`$TEST_API_PATH/anything/bar\` collapsed to a template or recorded verbatim in metric labels?
- [ ] P1: Trace attributes show the exact path segment or a template
- [ ] P2: \`$TEST_API_PATH/status/200\` and \`$TEST_API_PATH/status/404\` — distinct metric label combinations per path?
- [ ] P2: Are both paths visible in Jaeger with correct \`http.status_code\`?
- [ ] P3: All 5 distinct paths (/get /headers /anything/test /ip /uuid) visible as separate spans in Jaeger?
- [ ] Access logs include upstream address/path confirming strip-listen-path + path-prefix behaviour
- [ ] Analytics DB: does \`id.path\` show the gateway listen path (\`/httpbun-test/get\`), the stripped path (\`/get\`), or the upstream path (\`/test1/get\`)?
- [ ] Analytics DB: are variable segments (\`/anything/foo\` vs \`/anything/bar\`) stored separately or collapsed?
- [ ] Analytics DB: do \`hits\`, \`error\`, \`success\` counts match actual requests sent?
FOOTER
  } > "$REPORT_FILE"
  echo "    Report written: $REPORT_FILE"
}

# ─── Cleanup ──────────────────────────────────────────────────────────────────
cleanup_tmp() {
  rm -f "/tmp/path_section_"[0-3]"_${TIMESTAMP}.md"
  rm -f "/tmp/path_analytics_${TIMESTAMP}.md"
  # Delete the temporary test key
  if [[ -n "$TEST_KEY" ]]; then
    curl -sf -X DELETE "$DASHBOARD_URL/api/keys/$TEST_KEY" \
      -H "Authorization: $USER_KEY" >/dev/null 2>&1 || true
    echo "    Test key deleted"
  fi
}

# ─── Global state ─────────────────────────────────────────────────────────────
TEST_START=""
TOTAL_LOG_LINES=0
TEST_KEY=""
TEST_KEY_HASH=""

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  check_prereqs
  get_credentials
  resolve_api_id

  TEST_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  run_scenario 0
  run_scenario 1
  run_scenario 2
  run_scenario 3

  # Wait for analytics flush: gateway default purge ~10s, pump purge_delay 2s
  echo ""
  echo ">>> Waiting ${ANALYTICS_WAIT_SECS}s for Tyk analytics flush (gateway → Redis → MongoDB)"
  sleep "$ANALYTICS_WAIT_SECS"

  # Query Tyk analytics and write to temp file for inclusion in report
  local test_end_epoch
  test_end_epoch=$(date -u +%s)
  local test_start_epoch
  test_start_epoch=$(python3 -c "
import datetime, calendar
dt = datetime.datetime.strptime('$TEST_START', '%Y-%m-%dT%H:%M:%SZ')
print(calendar.timegm(dt.timetuple()))
")
  local analytics_tmp="/tmp/path_analytics_${TIMESTAMP}.md"
  {
    cat <<ANALYTICS_HEADER

---

## Tyk Analytics DB

Per-request records from MongoDB selective collection \`z_tyk_analyticz_<orgid>\`, queried via \`docker exec\`.
Key hash used for test requests: \`$TEST_KEY_HASH\`
Analytics window: $TEST_START → $(date -u +"%Y-%m-%dT%H:%M:%SZ")

> **Note:** The pump \`purge_delay\` is 2s; gateway analytics flush interval is ~10s.
> If this table is empty, increase \`ANALYTICS_WAIT_SECS\` (currently ${ANALYTICS_WAIT_SECS}s) and re-run.
> \`path\` = what Tyk normalized the path to (endpoint template if matched); \`rawpath\` = actual request path.

ANALYTICS_HEADER
    query_tyk_analytics "$test_start_epoch" "$test_end_epoch"
  } > "$analytics_tmp"
  echo "    Analytics written to $analytics_tmp"

  write_report
  cleanup_tmp

  echo ""
  echo "========================================================"
  echo "Path Signals Report complete!"
  echo "  Report: $REPORT_FILE"
  echo ""
  echo "Re-run: bash deployments/opentelemetry-demo/scripts/path-signals-report.sh"
  echo "========================================================"
}

main "$@"
