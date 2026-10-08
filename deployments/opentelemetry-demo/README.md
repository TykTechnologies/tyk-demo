# OpenTelemetry Demo

This deployment demonstrates Tyk's observability features using the [OpenTelemetry Demo](https://opentelemetry.io/docs/demo/) project. It showcases how Tyk integrates with modern observability tools including OpenTelemetry Collector, Jaeger for distributed tracing, Prometheus for metrics, and Grafana for visualization.

[OpenTelemetry Demo Architecture](./architecture.md)

## Setup

Run the `up.sh` script:

```
./up.sh opentelemetry-demo
```

## Usage

The deployment provides access to multiple observability dashboards and the demo application.

## Endpoints

| Application | Endpoint |
| ----------- | -------- |
| OpenTelemetry Demo UI | http://localhost:8085 |
| Jaeger UI | http://localhost:8085/jaeger/ui |
| Grafana UI | http://localhost:8085/grafana/ |
| Load Generator UI | http://localhost:8085/loadgen/ |
| Feature Flags | http://localhost:8085/feature/ |

## Environment

All configuration defaults for this deployment — demo app settings, service ports, and Tyk OTLP instrumentation — are provided by [`demo.env`](./demo.env). 

To modify any setting, either edit [`demo.env`](./demo.env) directly or add the variable to your `.env` file. Variables in `.env` take precedence over `demo.env`.

## Grafana Cloud Integration

All telemetry can be forwarded to Grafana Cloud alongside the local backends. Local services (Jaeger, Tempo, Prometheus, Loki, OpenSearch) continue running — Grafana Cloud is an additional destination.

### Prerequisites

You need three values from your Grafana Cloud stack:

| Variable | Description | Where to find it |
| -------- | ----------- | ---------------- |
| `GRAFANA_CLOUD_OTLP_ENDPOINT` | OTLP gateway URL for your region | Home → Connections → Add new connection → OpenTelemetry |
| `GRAFANA_CLOUD_INSTANCE_ID` | Your numeric Grafana Cloud instance ID | Same page — listed as "Instance ID" or "Username" |
| `GRAFANA_CLOUD_API_KEY` | A Grafana Cloud API token with MetricsPublisher + LogsPublisher + TracesPublisher scopes | Home → Administration → Service accounts → Add service account token |

Region endpoints:
- EU: `https://otlp-gateway-prod-eu-west-2.grafana.net/otlp`
- US East: `https://otlp-gateway-prod-us-east-0.grafana.net/otlp`
- AP Southeast: `https://otlp-gateway-prod-ap-southeast-1.grafana.net/otlp`

### Setup

**Step 1** — Set the environment variables in your `.env` file (takes precedence over `demo.env`):

```
GRAFANA_CLOUD_OTLP_ENDPOINT=https://otlp-gateway-prod-<region>.grafana.net/otlp
GRAFANA_CLOUD_INSTANCE_ID=<your instance ID>
GRAFANA_CLOUD_API_KEY=<your API token>
```

**Step 2** — Uncomment all sections in [`src/otel-collector/otelcol-config-extras.yml`](./src/otel-collector/otelcol-config-extras.yml):
remove the leading `# ` from every line in the `exporters`, `processors`, `extensions`, `connectors`, and `service` blocks.

**Step 3** — Restart the deployment:

```
./up.sh opentelemetry-demo
```

To verify, check the collector logs for any authentication errors:

```
docker logs otel-collector 2>&1 | grep -i "grafana\|export\|error"
```

## Grafana Dashboards

Grafana is available at **http://localhost:8085/grafana** (no login required).

The deployment ships four pre-configured dashboards that together give a complete picture of Tyk Gateway in production. They cross-link to each other so you can navigate seamlessly during a demo. Four more cover the control plane (Environments Overview, Tyk Dashboard, MDCB, Developer Portal): see [Control Plane Observability](#control-plane-observability-dashboard-mdcb-developer-portal).

---

### 1. Fleet Health — `tyk-gateway-fleet-health`

**Who it's for**: Platform engineers and DevOps teams managing multiple gateway instances.

**What it shows**:
- How many gateway instances are running and how many APIs/policies each has loaded
- Config drift — whether all gateways have the same number of APIs loaded (a sign of a sync problem)
- Go runtime health: heap memory pressure, GC goal, goroutine count
- Per-gateway request rate and traffic distribution
- Gateway error log histogram (error / warn / info stacked bars, last N minutes)
- Recent error log stream and upstream failure breakdown by API

**Demo talking points**:
- Open the Fleet Health dashboard and point out the KPI bar at the top — gateway count, total APIs loaded, fleet request rate.
- Show the Config Drift gauge: if all gateways are in sync it reads 0. Explain this catches split-brain scenarios where a reload didn't propagate.
- Scroll to Go Runtime Health — show heap pressure gauge. Explain this gives ops teams early warning before a gateway OOM-kills.
- Show the log histogram at the bottom. This is Loki-backed — no log agent needed on the gateway side, just structured JSON logs over OTLP.

---

### 2. API Portfolio Overview — `tyk-api-portfolio`

**Who it's for**: API platform leads and SRE on-call. The single-pane view across all APIs.

**What it shows**:
- Portfolio KPIs: total request rate, error rate, P95 latency, active API count
- Traffic trends over time and per-API breakdown
- Error analysis: error rate by API, error type distribution, top 10 APIs by error rate
- API Leaderboards: top 10 APIs by traffic, P95 latency, and error rate — showing API names, not raw UUIDs
- Multi-tenancy: traffic by organisation and tenant
- Consumer identity: traffic by API key, OAuth client, developer portal app
- SLO tracking: availability SLO gauge, error budget remaining, burn rate (1h and 6h), P95 latency vs threshold

**Demo talking points**:
- Start at the Portfolio KPI bar — these four numbers tell you the health of your entire API estate at a glance.
- Scroll to the API Leaderboards. Point out that bar labels show API names. Clicking a bar links directly into the Troubleshooting dashboard for that API — no copy-pasting IDs.
- Show the SLO section. Explain that `slo_availability_target` and `slo_latency_ms` are dashboard variables — you can change the target on the fly to model different SLO commitments.
- Show the Multi-Tenancy and Consumer Identity rows. These come from Tyk's custom OTLP instruments and require no code changes in the upstream services — they're derived from request metadata, headers, and session context.

**Filter interactions**: Clicking an API ID in the Latency by API table applies it as a dashboard filter, scoping all panels to that API.

---

### 3. API Troubleshooting — `tyk-api-troubleshooting`

**Who it's for**: Backend engineers and SRE on-call investigating a specific API.

**What it shows**:
- API-scoped KPIs: request rate, error rate, P95 latency, cache hit rate
- Latency attribution: how much of the end-to-end latency is the gateway vs the upstream
- Error breakdown: error rate over time with response flag detail (e.g. `URS` = upstream 5xx, `UT` = upstream timeout)
- Traffic patterns by gateway instance
- Upstream health: isolation of upstream-related response flags
- Distributed traces via Grafana Tempo: recent traces and error traces for the selected API
- Structured log analysis: access logs, error/warn logs, all logs with trace ID correlation

**Demo talking points**:
- Select a specific API from the `api_id` variable at the top.
- Show the Latency Attribution pie chart — it immediately answers "is the slowness in Tyk or in the backend?" without digging through logs.
- Open the Distributed Tracing row. Click a trace row — it links to the full trace in Tempo showing every span across all microservices. This is end-to-end visibility from the gateway to the upstream service, all correlated by trace ID.
- Show the Log Analysis row. Highlight the trace ID correlation: clicking a trace in Tempo gives you a trace ID, which you can paste into the `trace_id` variable to filter all log panels to that exact request.
- For the error traces table, trigger a 5xx by toggling a feature flag (http://localhost:8085/feature/) then show the error appearing in real time.

**Best entry point**: Arrive here from the API Portfolio Leaderboard by clicking "Troubleshoot this API" on any API bar.

---

### 4. Native OTLP Metrics Explorer — `tyk-gateway-otlp-metrics`

**Who it's for**: Engineers and solution architects exploring what Tyk's custom OTLP instrumentation can produce.

**What it shows**: All 19 OTLP instruments (4 default + 15 custom) across 13 rows covering traffic, latency, error analysis, method breakdown, and every available dimension source:
- Metadata dimensions: route, API version, organisation, scheme
- Session dimensions: API key (last 6 chars), OAuth client, developer portal app/org
- Header dimensions: tenant ID (`X-Tenant-ID`), customer ID (`X-Customer-ID`)
- Response header dimensions: cache status, backend version, content type
- Context dimensions: subscription tier, region (requires middleware to populate)
- Quota/rate-limit tracking via `X-RateLimit-Limit` response header

**Demo talking points**:
- This dashboard is the "what's possible" showcase. Open it after explaining that all these dimensions come for free from the gateway — no changes to upstream services.
- Scroll through the rows and explain each dimension source type: metadata (built-in request fields), session (auth session data), headers (any request/response header), context (Tyk middleware-set variables).
- Show the Session Dimensions row — API key traffic and OAuth client traffic are derived from Tyk's auth layer, zero instrumentation in application code.
- The Context Dimensions row (tier, region) shows placeholder values by default because it needs middleware to set context variables. Explain this as a pattern for custom enrichment — a Go plugin can inject any value and it flows through to metrics automatically.

---

### Suggested Demo Flow

For a **15-minute demo** to an audience unfamiliar with Tyk:

1. **Fleet Health** (2 min) — "Here's how platform ops see the gateway fleet."
2. **API Portfolio** (5 min) — "Here's the API estate view. Show SLOs, leaderboards, click through to troubleshooting."
3. **API Troubleshooting** (5 min) — "Here's how an SRE investigates a specific API. Show latency attribution, then drill into a trace."
4. **OTLP Metrics Explorer** (3 min) — "And here's everything you can measure out of the box, across 13 dimension categories."

For a **deep-dive demo** focused on a specific persona:
- **Platform ops**: Focus on Fleet Health — config drift, Go runtime, log histogram.
- **API product manager**: Focus on Portfolio — SLOs, error budget, consumer identity rows.
- **Backend engineer**: Focus on Troubleshooting — latency attribution + trace + log correlation.

---

## Control Plane Observability (Dashboard, MDCB, Developer Portal)

The Tyk Dashboard, MDCB and the Enterprise Developer Portal export their own OTLP metrics, the same way the Gateway does. This deployment collects them through the same OpenTelemetry Collector → Prometheus pipeline, and ships four Grafana dashboards and a set of Prometheus alert rules for them.

### Requirements

| Component | Minimum version | Metrics |
| --------- | --------------- | ------- |
| Tyk Dashboard | v5.16.0 | Management API HTTP, gateway registry, licence, change propagation, dependency pools and health, object inventory and governance, build info, Go runtime |
| Tyk MDCB | v2.14.0 | Data plane connectivity and churn, config and key sync, keyspace events, analytics ingestion, RPC load, connection pools, dependency health, licence and certificate expiry, build info, Go runtime |
| Tyk Developer Portal | v1.20.0 | Provider sync health, dependency health |
| Tyk Gateway | v5.16.0 | Reports its version and loaded APIs/policies to the Dashboard registry; older gateways show as `unknown` |
| Grafana | 13 | The Environments Overview is a Grafana v2 (dynamic) dashboard; this deployment runs Grafana 13.2.3 |

Older versions ignore the configuration; their dashboards simply stay empty. Data plane gateways must be connected to MDCB to appear on the MDCB dashboard. Pre-releases can be used by setting `DASHBOARD_VERSION`, `GATEWAY_VERSION`, `MDCB_VERSION` and `PORTAL_VERSION` in `.env` (for example `v5.16.0-alpha1`, `v2.14.0-alpha1`, `v1.20.0-alpha1`).

### Setup

Deploy the components you want alongside this deployment. MDCB requires `MDCB_LICENCE` in `.env` (see the [MDCB deployment](../mdcb/README.md)):

```
./up.sh opentelemetry-demo mdcb portal
```

The Tyk Dashboard always exports metrics with this deployment. MDCB and the Portal export them when their deployment is included. Configuration comes from [`demo.env`](./demo.env):

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `CONTROL_PLANE_ID` | `tyk-demo-cp` | `control_plane_id` label stamped on every control-plane series; dashboards and alerts group by it |
| `CONTROL_PLANE_ENVIRONMENT` | `demo` | `deployment_environment` label |
| `CONTROL_PLANE_METRICS_ENDPOINT` | `otel-collector:4317` | OTLP gRPC endpoint for all three components |
| `CONTROL_PLANE_METRICS_EXPORTINTERVAL` | `5` | Export interval, in seconds (the Gateways also export every 5s) |
| `TYK_DB_OPENTELEMETRY_METRICS_ENABLED` | `true` | Dashboard metrics on/off |
| `TYK_DB_OPENTELEMETRY_METRICS_OBJECTSMETRICS_COLLECTIONINTERVAL` | `60` | How often the Dashboard counts APIs, policies and users, in seconds |
| `TYK_MDCB_OPENTELEMETRY_METRICS_ENABLED` | `true` | MDCB metrics on/off |
| `PORTAL_OPENTELEMETRY_METRICS_ENABLED` | `true` | Portal metrics on/off |

The compose files map these to each component's own settings (`TYK_DB_OPENTELEMETRY_METRICS_*`, `TYK_MDCB_OPENTELEMETRY_METRICS_*`, `PORTAL_OPENTELEMETRY_METRICS_*`). The Portal has no `control_plane_id` setting, so it receives it through `OTEL_RESOURCE_ATTRIBUTES`.

### Control plane dashboards

The four dashboards share the same filters (data source, environment, control plane, and component replica) and link to each other, keeping the filters and time range. Every panel's description names the metric it reads. Data plane groups link to the Gateway Fleet Health dashboard with the group pre-selected.

#### 5. Tyk Environments Overview — `tyk-environments`

**Who it's for**: Platform owners and on-call SREs: the single pane for every environment and control plane.

**What it shows**:
- An environments table: control planes, dependency checks, connected gateways and data planes, gateway version drift, the licence or certificate that expires first, Developer Portal sync, and when checks last reported
- One section per environment, and inside it one per control plane:
  - Summary: dependency checks, gateway version drift against the Tyk Dashboard, first licence/certificate to expire, gateways by version
  - Tyk Dashboard: version, connected gateways, licence seats, API errors, datastore and Redis checks, certificates and licence expiry
  - MDCB (only when the control plane runs MDCB): version, data planes and their gateways, RPC errors, checks, data planes by group, certificates and licence
- The Developer Portal: instances, last successful provider sync, unreachable providers, failed syncs, database and file storage checks

Each section links to the component dashboard for that environment and control plane.

#### 6. Tyk Dashboard — `tyk-dashboard`

**Who it's for**: Platform teams running the management plane, and CI/CD owners asking "is it the Dashboard or my pipeline?".

**What it shows**: at-a-glance health; dependency checks and connection pool usage; gateways connected to the Dashboard (heartbeats, loaded config, versions, tags, segmentation, gateways that stopped heartbeating); certificates and licence seats and expiry; the control API (5xx rate, requests by status class, p50/p95/p99, busiest and slowest routes); change propagation to gateways; process and runtime; object inventory; and API governance compliance.

#### 7. Tyk MDCB — `tyk-mdcb`

**Who it's for**: SREs operating MDCB and the data planes behind it.

**What it shows**: at-a-glance health; data planes by group (gateways, change vs an hour ago, heartbeats, loaded config, versions), gateways that went missing, connection failures and reconnects; dependency checks and connection pools; RPC requests to MDCB (errors and denied, results, latency by method, top groups and gateways, data transferred); config and key sync (last successful sync, failures by cause, config change events, sync duration); certificates and licence; analytics ingestion; process and runtime.

**Demo talking points**:
- Stop a worker gateway (`docker stop tyk-demo-tyk-worker-gateway-1`): it moves to "Gateways that went missing" and its group's count drops, firing `TykMDCBGatewayHeartbeatStale` and `TykMDCBDataPlaneGroupDisconnected`.
- Create and delete a few keys in the Dashboard: config change events show what MDCB propagates to data planes, and deleted keys show up as `keys · not_found` sync failures (normal, so they do not alert).
- MDCB syncs a group when a gateway connects (bulk push) or after a change (pull), not on a timer, so an old "Last successful sync" on a stable estate is normal.
- RPC latency by method leaves out `CheckReload`/`CheckIdPReload`: gateways long-poll them and MDCB holds each call for about 1s by design.
- Call a protected API on the worker gateway with an invalid key (`curl -H 'Authorization: wrong' http://localhost:8090/basic-protected-api/get`): every lookup of a key that does not exist counts as a `GetKey` RPC error, so the RPC error ratio rises. `TykMDCBRPCErrorRate` ignores `GetKey` for this reason.
- Right after bootstrap, the RPC error and connection failure panels show a few minutes of `denied`/`invalid_credentials`: the worker gateways start before the MDCB bootstrap creates their Dashboard credentials. It clears once they restart with them, and is too short to fire the connection-error alert.

#### 8. Tyk Developer Portal — `tyk-portal`

**Who it's for**: Teams running the public developer storefront.

**What it shows**: at-a-glance health; provider sync with the Tyk Dashboard (time since the last successful sync, reachability, failures by cause: `auth`, `network`, `timeout`, `dashboard_error`, ..., and sync duration); database, file storage and process health.

**Demo talking points**:
- The time since the last successful sync resets every `PORTAL_REFRESHINTERVAL` (10 minutes here). A value that keeps climbing is the silent sync stall that today only shows up as stale catalogues.
- Rotate the Dashboard API key used by the provider to show `auth` failures, an unreachable provider, and the stale-sync alert.

### Control plane alert rules

[`src/prometheus/tyk-control-plane.rules.yml`](./src/prometheus/tyk-control-plane.rules.yml) is loaded by Prometheus and can be reused as-is in any Prometheus that ingests these metrics. Every alert has a `severity` (`critical`, `warning`, `info`) and a `tyk_component` label, plus `summary`, `description` and `dashboard` annotations. Firing alerts appear at http://localhost:8085/grafana/alerting/list (data source-managed rules).

| Alert | Severity | Fires when |
| ----- | -------- | ---------- |
| `TykControlPlaneComponentStoppedReporting` | critical | Dashboard, MDCB or Portal reported in the last 30 minutes but not in the last 5 |
| `TykControlPlaneComponentRestarted` | info | A replica started less than 5 minutes ago |
| `TykControlPlaneMemoryNearLimit` | warning | Go memory above 90% of `GOMEMLIMIT` for 10m |
| `TykDashboardDependencyUnhealthy` | critical | A Dashboard storage role (main, analytics, logs, uptime, Redis) fails its probe for 2m |
| `TykDashboardHighErrorRate` | warning | Management API 5xx rate above 5% for 5m |
| `TykDashboardHighLatency` | warning | Management API p95 above 2s for 10m |
| `TykDashboardGatewayHeartbeatStale` | warning | A registered gateway has not heartbeated for 60s |
| `TykDashboardConnectedGatewaysDropped` | warning | Fewer gateways registered than 15 minutes ago |
| `TykDashboardLicenseGatewayCapacity` | warning | More than 90% of licensed gateway slots in use |
| `TykDashboardLicenseExpiringSoon` / `TykDashboardLicenseExpiryImminent` | warning / critical | Licence expires within 30 / 7 days |
| `TykDashboardCertificateExpiringSoon` | warning | Dashboard TLS certificate expires within 14 days |
| `TykDashboardNotificationFailures` | warning | Changes failing to publish to gateways for 5m |
| `TykDashboardDatastorePoolSaturated` / `TykDashboardRedisPoolSaturated` | warning | Connection pool above 90% of its maximum for 5m |
| `TykDashboardTelemetryExporterUnhealthy` | warning | OTLP exports failing for 10m |
| `TykMDCBDependencyUnhealthy` | critical | MDCB datastore, Redis or RPC server unhealthy for 2m |
| `TykMDCBDataPlaneGroupDisconnected` | critical | Every gateway of a group that was connected in the last hour is gone |
| `TykMDCBDataPlaneGatewaysDropped` | warning | A group has fewer gateways than 15 minutes ago |
| `TykMDCBGatewayReconnectStorm` | warning | More than 5 reconnects/min in a group for 5m |
| `TykMDCBGatewayConnectErrors` | warning | More than 3 failed connection attempts/min of one cause for 10m |
| `TykMDCBGatewayHeartbeatStale` | warning | A registered gateway has made no login or sync call for 2 minutes |
| `TykMDCBGatewayConfigDrift` | warning | Gateways in the same group report different API counts for 10m |
| `TykMDCBGatewayVersionSkew` | info | More than one gateway version in a group for 30m |
| `TykMDCBRPCErrorRate` | warning | More than 5% of RPC calls failing for 5m (GetKey excluded: invalid client keys return errors) |
| `TykMDCBRPCSlow` | warning | p95 handler time of an RPC method above 500ms for 10m (polls excluded) |
| `TykMDCBRPCPoolSaturated` | warning | A connection pool above 80% of its maximum for 5m |
| `TykMDCBRPCConnectionsRejected` | critical | MDCB turning away connections because its pool is full |
| `TykMDCBSyncFailures` | warning | Config or key syncs to a group failing for 5m (`not_found` excluded) |
| `TykMDCBAnalyticsRecordsFailing` | warning | Analytics records failing to be stored for 5m |
| `TykMDCBTelemetryExporterUnhealthy` | warning | MDCB OTLP exports failing for 10m |
| `TykMDCBLicenseExpiringSoon` / `TykMDCBLicenseExpiryImminent` | warning / critical | MDCB licence expires within 30 / 7 days |
| `TykMDCBCertificateExpiringSoon` | warning | MDCB TLS certificate expires within 14 days |
| `TykPortalDependencyUnhealthy` | critical | Portal database or asset storage fails its probe for 2m |
| `TykPortalProviderSyncStale` | critical | No successful provider sync for 30 minutes (3 × `PORTAL_REFRESHINTERVAL`) |
| `TykPortalProviderUnreachable` | critical | The provider's Dashboard did not answer the last sync |
| `TykPortalProviderSyncFailing` | warning | Provider sync failures in the last 30 minutes |
| `TykPortalProviderSyncSlow` | warning | Provider sync p95 above 60s for 30m |

Thresholds are demo defaults; tune them per estate. The rules have unit tests:

```
docker run --rm -v "$PWD/deployments/opentelemetry-demo/src/prometheus:/p" -w /p/tests \
  --entrypoint promtool quay.io/prometheus/prometheus:v3.5.0 test rules tyk-control-plane.rules.test.yml
```

### Known limitations

- The Dashboard's per-gateway version and loaded API/policy counts need Gateway v5.16.0 or later; older gateways show `unknown` and empty counts.
- MDCB syncs on gateway login and reload rather than on a timer, so the age of the last successful sync is shown but not alerted on; sync failures are.
- The Portal does not yet export HTTP, authentication, provisioning or Go runtime metrics, so its dashboard covers provider sync and dependency health only.
- Prometheus misses the first increment of a counter series that starts mid-run, so a brand-new series (a gateway that just logged in, the first Portal sync or failure after a restart) shows up in rates from its second increment. The bulk API definition transfer a gateway receives at login is the most visible case in "RPC data transferred".
- MDCB v2.14.0-alpha1 forgets the last successful sync of every group if its node registry looks empty for a single export cycle (seen under load, when a gateway heartbeat is late). "Last successful sync" then shows no data until the group's gateways log in again or a change is pulled.
- A restarted gateway comes back with a new node ID. Series pushed over OTLP get no staleness marker when they stop, so Prometheus keeps returning the old ID's last value for up to 5 minutes: both IDs are listed (the old one with a growing heartbeat age) until it drops out.

---

## Generating Traffic

The deployment ships several scripts to populate the Grafana dashboards with realistic signal data. The built-in Locust load generator (accessible at `http://localhost:8085/loadgen/`) produces baseline traffic for the demo app services; the scripts below target Tyk-specific dimensions such as tenants, OAuth clients, backend versions, and quota tiers.

All scripts read credentials from `logs/bootstrap.log` and require the stack to be running.

---

### Continuous Load — `continuous-traffic-gen.js` (recommended)

Runs six traffic scenarios in parallel for a configurable duration using [k6](https://k6.io/). This is the recommended way to populate all dashboards in one step.

**Prerequisites**: k6 installed (`brew install k6` on macOS).

```bash
USER_API_KEY=$(grep "API Key:" logs/bootstrap.log | head -1 | awk '{print $NF}')
k6 run --env USER_API_KEY=$USER_API_KEY \
  deployments/opentelemetry-demo/scripts/continuous-traffic-gen.js
```

**Optional environment variables:**

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `GATEWAY_URL` | `http://tyk-gateway.localhost:8080` | Gateway base URL |
| `DURATION` | `30m` | How long to run |
| `CLEANUP` | `false` | Set `true` to delete created resources on teardown |

**Scenarios run concurrently:**

| Scenario | Rate | What it demonstrates |
| -------- | ---- | -------------------- |
| Tenant traffic | 1 req/2 s | Per-tenant request rate and latency (`X-Tenant-ID`, `X-Customer-ID`) |
| Version traffic | 1 req/3 s | Backend version distribution (v1/v2/v3 ratio 4:3:2) |
| OAuth traffic | 1 req/4 s | Per-OAuth-client request rate with token refresh |
| Cache traffic | 1 req/2 s | Cache hit/miss ratio (90 % hits) |
| Quota traffic | 1 req/3 s | Quota tier distribution (low/mid/high, includes 429s) |
| Rate limit burst | 5 req/1 s | Deliberate rate-limit exhaustion (~60 % 429 responses) |

---

### One-Shot Bash Scripts

Use these when you want to quickly populate a specific dashboard row without running k6.

#### Tenant & Customer Traffic — `tenant-traffic-gen.sh`

Generates 75 requests across three tenants (`tenant-alpha`, `tenant-beta`, `tenant-gamma`) with `X-Tenant-ID` and `X-Customer-ID` headers. Populates the **Multi-Tenancy** rows in the API Portfolio dashboard.

```bash
bash deployments/opentelemetry-demo/scripts/tenant-traffic-gen.sh
```

Runtime: ~75 seconds.

#### OAuth Client Traffic — `oauth-traffic-gen.sh`

Creates three OAuth 2.0 clients and generates 75 requests (60 success + 15 errors). Populates the **Consumer Identity — OAuth** panels.

```bash
bash deployments/opentelemetry-demo/scripts/oauth-traffic-gen.sh
```

Runtime: ~75 seconds.

#### Backend Version & Content-Type Traffic — `version-traffic-gen.sh`

Generates 90 requests routed to three mock backend versions in a 4:3:2 ratio. Populates the **Backend Version Distribution** and **Response Content-Type Mix** panels.

```bash
bash deployments/opentelemetry-demo/scripts/version-traffic-gen.sh
```

Runtime: ~45 seconds.

#### Cache, Quota & Rate-Limit Traffic — `traffic-control-demo.sh`

Runs four sequential scenarios: cache hit/miss, quota tier distribution, quota exhaustion (429s), and rate-limit burst. Populates the **Cache**, **Quota**, and **Rate Limit** panels.

```bash
bash deployments/opentelemetry-demo/scripts/traffic-control-demo.sh
```

Runtime: ~14 seconds.

---

### Diagnostic & Report Scripts

These scripts capture a snapshot of gateway telemetry (metrics, logs, traces) into a timestamped Markdown report in the `reports/` directory. Useful for verifying instrumentation or sharing signal samples.

#### Gateway Signals Report — `gateway-signals-report.sh`

Provisions a test API, runs auth and error scenarios, then queries Prometheus metrics, gateway container logs, and Jaeger traces. Output: `reports/gateway-signals-report-YYYYMMDD-HHMMSS.md`.

```bash
bash deployments/opentelemetry-demo/scripts/gateway-signals-report.sh
```

#### Path Signals Report — `path-signals-report.sh`

Tests path-dimension telemetry across metrics (`listen_path`, `endpoint`), access logs, and trace span attributes (`http.url`, `http.target`, `http.route`). Output: `reports/path-signals-report-YYYYMMDD-HHMMSS.md`.

```bash
bash deployments/opentelemetry-demo/scripts/path-signals-report.sh
```

---

## Configuration

This deployment demonstrates several key observability features:

### Distributed Tracing
- **Jaeger**: Collects and visualizes distributed traces from the demo application
- **OpenTelemetry Collector**: Receives, processes, and exports telemetry data
- **Tyk Integration**: Gateway traces are correlated with application traces

### Metrics Collection
- **Prometheus**: Scrapes metrics from all services including **Tyk Pump**
- **OpenTelemetry Metrics**: Application metrics exported via OTLP protocol
- **Custom Dashboards**: Pre-configured Grafana dashboards for visualization

### Demo Application Services
The deployment includes a complete microservices application with:
- **Frontend**: Web UI for the online shop
- **Product Catalog**: Product information service
- **Cart Service**: Shopping cart management
- **Checkout Service**: Order processing
- **Payment Service**: Payment processing
- **Shipping Service**: Shipping calculations
- **Email Service**: Email notifications
- **Ad Service**: Advertisement service
- **Recommendation Service**: Product recommendations
- **Currency Service**: Currency conversion
- **Fraud Detection**: Transaction fraud detection
- **Accounting Service**: Financial accounting

These services are proxied through Tyk Gateway, and the API configurations are located in the `/apps` directory.

### Key Features Demonstrated
- End-to-end distributed tracing across microservices
- Metrics collection and visualization
- Error tracking and monitoring
- Performance monitoring and alerting
- Service dependency mapping
- Real-time observability dashboards

This deployment provides a comprehensive example of how Tyk's observability features work in a realistic microservices environment, making it ideal for understanding and demonstrating modern API gateway observability capabilities.