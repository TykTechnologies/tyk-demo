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

The deployment ships four pre-configured dashboards that together give a complete picture of Tyk Gateway in production. They cross-link to each other so you can navigate seamlessly during a demo.

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