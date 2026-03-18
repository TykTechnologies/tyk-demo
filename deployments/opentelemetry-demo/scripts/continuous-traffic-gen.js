/**
 * Continuous Traffic Generator for Tyk Demo OTel Observability
 *
 * Replicates all four one-shot bash scripts in a single k6 script that runs
 * continuously, producing sustained signal across all Grafana dashboards.
 *
 * Setup: creates (or recreates) all required Tyk APIs, policies, keys and
 * OAuth clients once before traffic begins.
 *
 * Usage:
 *   USER_API_KEY=$(grep "API Key:" logs/bootstrap.log | head -1 | awk '{print $NF}')
 *   k6 run --env USER_API_KEY=$USER_API_KEY \
 *           deployments/opentelemetry-demo/scripts/continuous-traffic-gen.js
 *
 * Options (via --env):
 *   GATEWAY_URL   default: http://tyk-gateway.localhost:8080
 *   DASHBOARD_URL default: http://tyk-dashboard.localhost:3000
 *   GATEWAY_SECRET default: 28d220fd77974a4facfb07dc1e49c2aa
 *   DURATION      default: 30m
 *   CLEANUP       set to "true" to delete created resources on teardown
 */

import http from 'k6/http';
import { check } from 'k6';
import encoding from 'k6/encoding';

// ─── Config ────────────────────────────────────────────────────────────────────

const GATEWAY_URL = __ENV.GATEWAY_URL || 'http://tyk-gateway.localhost:8080';
const DASHBOARD_URL = __ENV.DASHBOARD_URL || 'http://tyk-dashboard.localhost:3000';
const GATEWAY_SECRET = __ENV.GATEWAY_SECRET || '28d220fd77974a4facfb07dc1e49c2aa';
const USER_API_KEY = __ENV.USER_API_KEY || '';
const DURATION = __ENV.DURATION || '30m';

// ─── Scenarios ─────────────────────────────────────────────────────────────────

export const options = {
  scenarios: {
    tenant_traffic: {
      executor: 'constant-arrival-rate',
      exec: 'tenantTraffic',
      rate: 1,
      timeUnit: '2s',
      duration: DURATION,
      preAllocatedVUs: 3,
    },
    version_traffic: {
      executor: 'constant-arrival-rate',
      exec: 'versionTraffic',
      rate: 1,
      timeUnit: '3s',
      duration: DURATION,
      preAllocatedVUs: 2,
    },
    oauth_traffic: {
      executor: 'constant-arrival-rate',
      exec: 'oauthTraffic',
      rate: 1,
      timeUnit: '4s',
      duration: DURATION,
      preAllocatedVUs: 2,
    },
    cache_traffic: {
      executor: 'constant-arrival-rate',
      exec: 'cacheTraffic',
      rate: 1,
      timeUnit: '2s',
      duration: DURATION,
      preAllocatedVUs: 2,
    },
    quota_traffic: {
      executor: 'constant-arrival-rate',
      exec: 'quotaTraffic',
      rate: 1,
      timeUnit: '3s',
      duration: DURATION,
      preAllocatedVUs: 2,
    },
    rate_limit_traffic: {
      executor: 'constant-arrival-rate',
      exec: 'rateLimitTraffic',
      rate: 5,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: 3,
    },
  },
};

// ─── Per-VU state ──────────────────────────────────────────────────────────────
// k6 gives each VU its own JS context, so module-level variables are per-VU.

const _counters = {};
const _oauthTokens = {};

function counter(name) {
  _counters[name] = (_counters[name] || 0) + 1;
  return _counters[name] - 1;
}

// ─── Setup helpers ─────────────────────────────────────────────────────────────

function authHeaders() {
  return { 'Authorization': USER_API_KEY, 'Content-Type': 'application/json' };
}

function reloadGateway() {
  const resp = http.get(`${GATEWAY_URL}/tyk/reload/group?block=true`, {
    headers: { 'x-tyk-authorization': GATEWAY_SECRET },
  });
  console.log(`Gateway reload: ${resp.json('status')}`);
}

function deleteApisByListenPaths(paths) {
  const resp = http.get(`${DASHBOARD_URL}/api/apis?p=-1`, {
    headers: { 'Authorization': USER_API_KEY },
  });
  const apis = (resp.json('apis') || []);
  for (const api of apis) {
    const lp = (api.api_definition && api.api_definition.proxy && api.api_definition.proxy.listen_path) || '';
    if (paths.indexOf(lp) !== -1) {
      const apiId = api.api_definition.api_id;
      http.del(`${DASHBOARD_URL}/api/apis/${apiId}`, null, {
        headers: { 'Authorization': USER_API_KEY },
      });
      console.log(`Deleted stale API: ${apiId} (${lp})`);
    }
  }
}

function deletePoliciesByNames(names) {
  const resp = http.get(`${DASHBOARD_URL}/api/portal/policies?p=-1`, {
    headers: { 'Authorization': USER_API_KEY },
  });
  const policies = (resp.json('Data') || []);
  for (const policy of policies) {
    if (names.indexOf(policy.name) !== -1) {
      http.del(`${DASHBOARD_URL}/api/portal/policies/${policy._id}`, null, {
        headers: { 'Authorization': USER_API_KEY },
      });
      console.log(`Deleted stale policy: ${policy._id} (${policy.name})`);
    }
  }
}

function createApi(def) {
  const resp = http.post(`${DASHBOARD_URL}/api/apis`, JSON.stringify(def), {
    headers: authHeaders(),
  });
  check(resp, { 'api created (200/201)': (r) => r.status === 200 || r.status === 201 });
  const docId = resp.json('Meta');
  const apiResp = http.get(`${DASHBOARD_URL}/api/apis/${docId}`, {
    headers: { 'Authorization': USER_API_KEY },
  });
  const apiId = apiResp.json('api_definition.api_id');
  console.log(`  Created API "${def.api_definition.name}": ${apiId}`);
  return apiId;
}

function createPolicy(def) {
  const resp = http.post(`${DASHBOARD_URL}/api/portal/policies`, JSON.stringify(def), {
    headers: authHeaders(),
  });
  check(resp, { 'policy created': (r) => r.status === 200 || r.status === 201 });
  // Dashboard API returns the policy ID in 'Message', not '_id'
  const id = resp.json('_id') || resp.json('Message');
  console.log(`  Created policy "${def.name}": ${id}`);
  return id;
}

function createKey(orgId, policyId) {
  const payload = {
    apply_policy_id: policyId,
    org_id: orgId,
    allowance: 0,
    rate: 0,
    per: 0,
    expires: -1,
    quota_max: -1,
    quota_renewal_rate: 3600,
    quota_remaining: -1,
    quota_renews: 0,
    is_inactive: false,
    access_rights: {},
  };
  const resp = http.post(`${DASHBOARD_URL}/api/keys`, JSON.stringify(payload), {
    headers: authHeaders(),
  });
  check(resp, { 'key created': (r) => r.status === 200 || r.status === 201 });
  const data = resp.json();
  return data.key_id || data.key || data.key_hash;
}

function fetchOAuthToken(clientId, clientSecret) {
  const basic = encoding.b64encode(`${clientId}:${clientSecret}`);
  const resp = http.post(
    `${GATEWAY_URL}/oauth-demo/oauth/token/`,
    'grant_type=client_credentials',
    {
      headers: {
        'Authorization': `Basic ${basic}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    }
  );
  check(resp, { 'oauth token fetched': (r) => r.status === 200 });
  return resp.json('access_token');
}

// ─── Setup ─────────────────────────────────────────────────────────────────────

export function setup() {
  if (!USER_API_KEY) {
    throw new Error(
      'USER_API_KEY is required.\n' +
      "  Extract it with: grep \"API Key:\" logs/bootstrap.log | head -1 | awk '{print $NF}'\n" +
      '  Then pass it: k6 run --env USER_API_KEY=<key> ...'
    );
  }

  // 1. Get org_id
  const usersResp = http.get(`${DASHBOARD_URL}/api/users`, {
    headers: { 'Authorization': USER_API_KEY },
  });
  check(usersResp, { 'got org_id': (r) => r.status === 200 });
  const users = usersResp.json('users');
  const orgId = users[0].org_id;
  console.log(`Org ID: ${orgId}`);

  // 2. Clean up stale resources
  console.log('Cleaning up stale APIs and policies...');
  deleteApisByListenPaths(['/tenant-demo/', '/version-demo/', '/oauth-demo/', '/cache-demo/', '/quota-demo/']);
  deletePoliciesByNames(['OAuth Demo Policy', 'Quota Low Policy', 'Quota Mid Policy', 'Quota High Policy', 'Rate Limit Burst Policy']);

  // 3. Create APIs
  console.log('Creating APIs...');

  const tenantApiId = createApi({
    api_definition: {
      name: 'Tenant Demo API', slug: 'tenant-demo', api_id: '', org_id: orgId,
      use_keyless: true, use_oauth2: false, active: true,
      proxy: { listen_path: '/tenant-demo/', target_url: 'http://httpbin/', strip_listen_path: true },
      version_data: {
        not_versioned: true, default_version: 'Default',
        versions: { Default: { name: 'Default', use_extended_paths: true, extended_paths: {} } },
      },
    },
    hook_references: [], is_site: false, sort_by: 0, user_group_owners: [], user_owners: [],
  });

  const _versionApiId = createApi({
    api_definition: {
      name: 'Version Demo API #otel-demo', slug: 'version-demo', api_id: '', org_id: orgId,
      use_keyless: true, use_oauth2: false, active: true, enable_detailed_recording: true,
      proxy: { listen_path: '/version-demo/', target_url: 'http://httpbin/', strip_listen_path: true },
      version_data: {
        not_versioned: true, default_version: 'Default',
        versions: { Default: { name: 'Default', use_extended_paths: true, extended_paths: {} } },
      },
    },
    hook_references: [], is_site: false, sort_by: 0, user_group_owners: [], user_owners: [],
  });

  const oauthApiId = createApi({
    api_definition: {
      name: 'OAuth Demo API', slug: 'oauth-demo', api_id: '', org_id: orgId,
      use_keyless: false, use_oauth2: true, active: true,
      oauth_meta: { allowed_access_types: ['client_credentials'], allowed_authorize_types: [], auth_login_redirect: '' },
      auth: { auth_header_name: 'Authorization' },
      notifications: { shared_secret: '', oauth_on_keychange_url: '' },
      proxy: { listen_path: '/oauth-demo/', target_url: 'http://httpbin/', strip_listen_path: true },
      version_data: {
        not_versioned: true, default_version: 'Default',
        versions: { Default: { name: 'Default', use_extended_paths: true, extended_paths: {} } },
      },
    },
    hook_references: [], is_site: false, sort_by: 0, user_group_owners: [], user_owners: [],
  });

  const _cacheApiId = createApi({
    api_definition: {
      name: 'Cache Demo API', slug: 'cache-demo', api_id: '', org_id: orgId,
      use_keyless: true, active: true,
      proxy: { listen_path: '/cache-demo/', target_url: 'http://httpbin/', strip_listen_path: true },
      cache_options: { cache_timeout: 60, enable_cache: true, cache_all_safe_requests: true, cache_response_codes: [200] },
      version_data: {
        not_versioned: true, default_version: 'Default',
        versions: { Default: { name: 'Default', use_extended_paths: true, extended_paths: {} } },
      },
    },
    hook_references: [], is_site: false, sort_by: 0, user_group_owners: [], user_owners: [],
  });

  const quotaApiId = createApi({
    api_definition: {
      name: 'Quota Demo API', slug: 'quota-demo', api_id: '', org_id: orgId,
      use_keyless: false, use_oauth2: false, active: true,
      auth: { auth_header_name: 'x-api-key' },
      proxy: { listen_path: '/quota-demo/', target_url: 'http://httpbin/', strip_listen_path: true },
      version_data: {
        not_versioned: true, default_version: 'Default',
        versions: { Default: { name: 'Default', use_extended_paths: true, extended_paths: {} } },
      },
    },
    hook_references: [], is_site: false, sort_by: 0, user_group_owners: [], user_owners: [],
  });

  // 4. Reload gateway so APIs are registered
  console.log('Reloading gateway after API creation...');
  reloadGateway();

  // 5. Create OAuth access policy
  console.log('Creating policies...');
  const oauthPolicyId = createPolicy({
    name: 'OAuth Demo Policy', rate: 1000, per: 60, quota_max: -1, quota_renewal_rate: -1,
    org_id: orgId, active: true, tags: [], is_inactive: false,
    access_rights: {
      [oauthApiId]: { api_id: oauthApiId, api_name: 'OAuth Demo API', versions: ['Default'] },
    },
  });

  // 6. Create quota policies (low=30/day@2rps, mid=100/day@10rps, high=500/day@50rps)
  const polLowId = createPolicy({
    name: 'Quota Low Policy', rate: 2, per: 1, quota_max: 30, quota_renewal_rate: 3600,
    org_id: orgId, active: true, tags: [], is_inactive: false,
    access_rights: {
      [quotaApiId]: { api_id: quotaApiId, api_name: 'Quota Demo API', versions: ['Default'] },
    },
  });
  const polMidId = createPolicy({
    name: 'Quota Mid Policy', rate: 10, per: 1, quota_max: 100, quota_renewal_rate: 3600,
    org_id: orgId, active: true, tags: [], is_inactive: false,
    access_rights: {
      [quotaApiId]: { api_id: quotaApiId, api_name: 'Quota Demo API', versions: ['Default'] },
    },
  });
  const polHighId = createPolicy({
    name: 'Quota High Policy', rate: 50, per: 1, quota_max: 500, quota_renewal_rate: 3600,
    org_id: orgId, active: true, tags: [], is_inactive: false,
    access_rights: {
      [quotaApiId]: { api_id: quotaApiId, api_name: 'Quota Demo API', versions: ['Default'] },
    },
  });
  // Rate-limit burst policy: low rate (2 req/s) but unlimited quota so rejections are
  // always 429 (rate limited) rather than 403 (quota exhausted)
  const polBurstId = createPolicy({
    name: 'Rate Limit Burst Policy', rate: 2, per: 1, quota_max: -1, quota_renewal_rate: -1,
    org_id: orgId, active: true, tags: [], is_inactive: false,
    access_rights: {
      [quotaApiId]: { api_id: quotaApiId, api_name: 'Quota Demo API', versions: ['Default'] },
    },
  });

  // 7. Reload gateway to sync new policies
  console.log('Reloading gateway to sync policies...');
  reloadGateway();

  // 8. Create quota API keys
  console.log('Creating keys...');
  const keyLow = createKey(orgId, polLowId);
  const keyMid = createKey(orgId, polMidId);
  const keyHigh = createKey(orgId, polHighId);
  const keyBurst = createKey(orgId, polBurstId);
  console.log(`  key-low: ${keyLow}  key-mid: ${keyMid}  key-high: ${keyHigh}  key-burst: ${keyBurst}`);

  // 9. Create OAuth clients
  console.log('Creating OAuth clients...');
  const oauthClients = [
    { id: 'client-alpha', secret: 'secret-client-alpha' },
    { id: 'client-beta',  secret: 'secret-client-beta'  },
    { id: 'client-gamma', secret: 'secret-client-gamma' },
  ];
  for (const client of oauthClients) {
    const resp = http.post(
      `${DASHBOARD_URL}/api/apis/oauth/${oauthApiId}`,
      JSON.stringify({
        api_id: oauthApiId,
        client_id: client.id,
        secret: client.secret,
        redirect_uri: 'http://localhost',
        policy_id: oauthPolicyId,
      }),
      { headers: authHeaders() }
    );
    console.log(`  OAuth client: ${resp.json('client_id')}`);
  }

  // 10. Get initial access tokens for each OAuth client
  console.log('Fetching OAuth access tokens...');
  const tokens = {};
  for (const client of oauthClients) {
    tokens[client.id] = fetchOAuthToken(client.id, client.secret);
    console.log(`  ${client.id}: ${String(tokens[client.id]).substring(0, 24)}...`);
  }

  console.log('\nSetup complete — traffic scenarios starting.\n');

  return {
    orgId,
    oauthClients,
    tokens,
    quotaKeys: { low: keyLow, mid: keyMid, high: keyHigh, burst: keyBurst },
  };
}

// ─── Scenario: Tenant Traffic ──────────────────────────────────────────────────
// Replicates tenant-traffic-gen.sh
// Metrics: tyk_requests_by_tenant_total, tyk_latency_by_tenant_seconds,
//          tyk_requests_by_customer_total (panels 131–134)

const TENANTS   = ['tenant-alpha', 'tenant-beta', 'tenant-gamma'];
const CUSTOMERS = ['cust-001', 'cust-002', 'cust-003'];

export function tenantTraffic(_data) {
  const n = counter('tenant');
  const tenant   = TENANTS[n % TENANTS.length];
  const customer = CUSTOMERS[n % CUSTOMERS.length];
  // Every 5th request generates a 500 to populate error-rate panels
  const isError = (n % 5 === 4);
  const url = isError
    ? `${GATEWAY_URL}/tenant-demo/status/500`
    : `${GATEWAY_URL}/tenant-demo/get`;

  const resp = http.get(url, {
    headers: { 'X-Tenant-ID': tenant, 'X-Customer-ID': customer },
  });
  check(resp, {
    'tenant traffic: expected status': (r) => isError ? r.status === 500 : r.status === 200,
  });
}

// ─── Scenario: Version Traffic ─────────────────────────────────────────────────
// Replicates version-traffic-gen.sh
// Metrics: tyk_requests_by_backend_version_total, tyk_requests_by_content_type_total
//          (panels 144–145)

// 9 slots to achieve v1:v2:v3 = 4:3:2 ratio
const VERSION_PATHS = [
  'response-headers?X-Backend-Version=v1&Content-Type=application/json',
  'response-headers?X-Backend-Version=v1&Content-Type=application/json',
  'response-headers?X-Backend-Version=v1&Content-Type=application/json',
  'response-headers?X-Backend-Version=v1&Content-Type=application/json',
  'response-headers?X-Backend-Version=v2&Content-Type=text/html',
  'response-headers?X-Backend-Version=v2&Content-Type=text/html',
  'response-headers?X-Backend-Version=v2&Content-Type=text/html',
  'response-headers?X-Backend-Version=v3&Content-Type=application/gzip',
  'response-headers?X-Backend-Version=v3&Content-Type=application/gzip',
];

export function versionTraffic(_data) {
  const n = counter('version');
  const path = VERSION_PATHS[n % VERSION_PATHS.length];
  const resp = http.get(`${GATEWAY_URL}/version-demo/${path}`);
  check(resp, { 'version traffic: status 200': (r) => r.status === 200 });
}

// ─── Scenario: OAuth Traffic ───────────────────────────────────────────────────
// Replicates oauth-traffic-gen.sh
// Metrics: tyk_requests_by_oauth_total (panels 123–124)

export function oauthTraffic(data) {
  const n = counter('oauth');
  const client = data.oauthClients[n % data.oauthClients.length];

  // Use per-VU token cache; fall back to initial tokens from setup
  let token = _oauthTokens[client.id] || data.tokens[client.id];

  // Every 5th request generates a 500 to populate error-rate panels
  const isError = (n % 5 === 4);
  const url = isError
    ? `${GATEWAY_URL}/oauth-demo/status/500`
    : `${GATEWAY_URL}/oauth-demo/get`;

  let resp = http.get(url, { headers: { 'Authorization': `Bearer ${token}` } });

  // Refresh token on 401 (expired) and retry once
  if (resp.status === 401) {
    token = fetchOAuthToken(client.id, client.secret);
    _oauthTokens[client.id] = token;
    resp = http.get(url, { headers: { 'Authorization': `Bearer ${token}` } });
  }

  check(resp, {
    'oauth traffic: expected status': (r) => r.status === 200 || r.status === 500,
  });
}

// ─── Scenario: Cache Traffic ───────────────────────────────────────────────────
// Replicates the cache portion of traffic-control-demo.sh
// Metrics: tyk_requests_with_cache_total (panels 141–143)

export function cacheTraffic(_data) {
  const n = counter('cache');
  // 10% of requests hit a unique path (cache miss); 90% reuse the same path (cache hit)
  const isMiss = (n % 10 === 0);
  const url = isMiss
    ? `${GATEWAY_URL}/cache-demo/anything/miss-${n}` // unique → miss
    : `${GATEWAY_URL}/cache-demo/get`;               // fixed  → hit after first request

  const resp = http.get(url, { headers: { 'x-request-id': 'cache-test' } });
  check(resp, { 'cache traffic: status 200': (r) => r.status === 200 });
}

// ─── Scenario: Quota Traffic ───────────────────────────────────────────────────
// Replicates the quota portion of traffic-control-demo.sh
// Metrics: tyk_requests_by_quota_limit_total, tyk_api_requests_total{429}
//          (panels 171–174)

export function quotaTraffic(data) {
  const n = counter('quota');
  const { low, mid, high } = data.quotaKeys;
  // 10-slot distribution: low≈30%, mid≈40%, high≈30%
  const slots = [low, low, low, mid, mid, mid, mid, high, high, high];
  const key = slots[n % slots.length];

  const resp = http.get(`${GATEWAY_URL}/quota-demo/get`, {
    headers: { 'x-api-key': key },
  });
  // 429 (rate limit) and 403 (quota exhausted) are expected and populate rejection panels
  check(resp, {
    'quota traffic: ok or rejected': (r) => r.status === 200 || r.status === 429 || r.status === 403,
  });
}

// ─── Scenario: Rate Limit Traffic ─────────────────────────────────────────────
// Deliberately fires at 5 req/s against a key limited to 2 req/s, producing a
// steady stream of 429 (rate limited) responses. The policy has quota_max=-1 so
// rejections are always 429, never 403 (quota exhausted).

export function rateLimitTraffic(data) {
  const resp = http.get(`${GATEWAY_URL}/quota-demo/get`, {
    headers: { 'x-api-key': data.quotaKeys.burst },
  });
  // ~60% of requests will be 429 (rate limited) at 5 req/s vs 2 req/s limit
  check(resp, {
    'rate limit traffic: ok or rate limited': (r) => r.status === 200 || r.status === 429,
  });
}

// ─── Teardown ──────────────────────────────────────────────────────────────────

export function teardown(_data) {
  if (__ENV.CLEANUP !== 'true') {
    console.log('Teardown: skipping cleanup (pass --env CLEANUP=true to remove resources)');
    return;
  }
  console.log('Teardown: removing created APIs and policies...');
  deleteApisByListenPaths(['/tenant-demo/', '/version-demo/', '/oauth-demo/', '/cache-demo/', '/quota-demo/']);
  deletePoliciesByNames(['OAuth Demo Policy', 'Quota Low Policy', 'Quota Mid Policy', 'Quota High Policy', 'Rate Limit Burst Policy']);
  console.log('Teardown complete.');
}
