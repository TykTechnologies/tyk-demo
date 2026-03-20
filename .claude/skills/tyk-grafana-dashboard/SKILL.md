---
name: tyk-grafana-dashboard
description: Expert assistant for designing and debugging the Tyk Gateway OTLP Grafana dashboard suite (Fleet Health, API Portfolio, API Troubleshooting, Native OTLP Metrics). Knows panel IDs, PromQL/LogQL/TraceQL patterns, metric names, dimension sources, and MCP tools for live Prometheus/Loki/Tempo/Grafana queries.
---

You are an expert on the **Tyk Gateway OTLP Grafana dashboard suite** — 4 interconnected dashboards covering fleet operations, API portfolio visibility, per-API troubleshooting, and custom OTLP metric exploration. You know every panel, every metric, every query pattern, and all MCP tools needed to inspect, modify, and debug any dashboard in this suite.

---

## 1. Dashboard Inventory

### Overview

All files are under `deployments/opentelemetry-demo/src/grafana/provisioning/dashboards/`. Grafana base URL: `http://localhost:8085/grafana`. Dashboards 2–4 cross-link to each other via the dashboard-level `links` array (see Section 14).

| # | UID | Title | File | Datasources | Audience |
|---|-----|-------|------|-------------|----------|
| 1 | `tyk-gateway-otlp-metrics` | Tyk Gateway — Native OTLP Metrics | `tyk-demo-backup/tyk-gateway-otlp-metrics.json` | Prometheus | Engineers exploring custom metrics |
| 2 | `tyk-gateway-fleet-health` | Tyk Gateway — Fleet Health | `tyk-demo/tyk-gateway-fleet-health.json` | Prometheus + Loki | Platform / DevOps |
| 3 | `tyk-api-portfolio` | Tyk Gateway — API Portfolio Overview | `tyk-demo/tyk-api-portfolio.json` | Prometheus | API platform leads, SRE on-call |
| 4 | `tyk-api-troubleshooting` | Tyk Gateway — API Troubleshooting | `tyk-demo/tyk-api-troubleshooting.json` | Prometheus + Tempo + Loki | Backend engineers, SRE on-call |

### tyk-gateway-otlp-metrics

- **UID**: `tyk-gateway-otlp-metrics`
- **File**: `tyk-demo-backup/tyk-gateway-otlp-metrics.json`
- **Refresh**: 30s | **Default range**: now-1h

#### Panel Index (56 data panels)

| ID | Type | Title | Row |
|----|------|-------|-----|
| 1 | stat | Request Rate | 1 – KPI Overview |
| 2 | stat | HTTP Error Rate | 1 |
| 3 | stat | P95 Total Latency | 1 |
| 4 | stat | P95 Gateway Latency | 1 |
| 5 | stat | P95 Upstream Latency | 1 |
| 6 | stat | Active APIs | 1 |
| 8 | timeseries | Request Rate by Status Class | 2 – Traffic Overview |
| 9 | timeseries | Request Rate by API | 2 |
| 11 | timeseries | Latency Breakdown: Total vs Gateway vs Upstream (P95) | 3 – Latency Attribution |
| 12 | piechart | Latency Attribution: Gateway vs Upstream | 3 |
| 13 | table | Latency by API (P50/P95/P99) — Total, Gateway, Upstream | 3 |
| 21 | timeseries | Error Rate Over Time by Status Code | 4 – Error Analysis |
| 22 | piechart | Response Flag Distribution | 4 |
| 23 | barchart | Status Code Distribution | 4 |
| 31 | bargauge | Top 10 APIs by Request Rate | 5 – API Leaderboards |
| 32 | bargauge | Top 10 APIs by P95 Latency | 5 |
| 33 | bargauge | Top 10 APIs by Error Rate | 5 |
| 41 | timeseries | Request Rate by HTTP Method | 6 – Method Breakdown |
| 42 | timeseries | P95 Latency by HTTP Method | 6 |
| 51 | timeseries | Gateway Total Request Counter | 7 – Gateway Counter |
| 52 | timeseries | Request Rate vs Error Rate Correlation | 7 |
| 111 | bargauge | Top Routes by Traffic | 9 – Metadata Dimensions |
| 112 | timeseries | Route Error Rate Over Time | 9 |
| 113 | timeseries | Traffic by Organization | 9 |
| 114 | piechart | Traffic Share by API Version | 9 |
| 115 | table | API Version Error Rate & Traffic | 9 |
| 116 | stat | HTTPS Traffic % | 9 |
| 117 | timeseries | Requests by Scheme (HTTP vs HTTPS) | 9 |
| 121 | bargauge | Top API Keys by Traffic (last 6 chars) | 10 – Session Dimensions |
| 122 | timeseries | API Key Traffic Over Time | 10 |
| 123 | timeseries | OAuth Client Traffic | 10 |
| 124 | bargauge | OAuth Client Error Rate (Top 10) | 10 |
| 125 | piechart | Portal App Usage Share | 10 |
| 126 | timeseries | Portal Org Traffic Trends | 10 |
| 131 | timeseries | Per-Tenant Request Rate | 11 – Header Dimensions |
| 132 | timeseries | Tenant Error Rate | 11 |
| 133 | bargauge | Per-Tenant P95 Latency | 11 |
| 134 | table | Tenant SLO Dashboard | 11 |
| 135 | timeseries | Per-Customer Request Rate | 11 |
| 136 | bargauge | Top Customers by Traffic | 11 |
| 141 | stat | Cache Hit Rate | 12 – Response Header Dims |
| 142 | timeseries | Cache Status Over Time | 12 |
| 143 | piechart | Cache Status Breakdown | 12 |
| 144 | timeseries | Backend Version Distribution Over Time | 12 |
| 145 | piechart | Response Content-Type Mix | 12 |
| 171 | stat | 429 Rejection % | 12 |
| 172 | timeseries | 429 Rejections Over Time | 12 |
| 173 | bargauge | Top APIs by 429 Rejections | 12 |
| 174 | timeseries | Traffic by Quota Tier | 12 |
| 151 | timeseries | Traffic by Subscription Tier | 13 – Context Dimensions |
| 152 | piechart | Tier Traffic Share | 13 |
| 153 | bargauge | Per-Tier P95 Latency | 13 |
| 154 | timeseries | Tier Error Rate | 13 |
| 155 | timeseries | Request Rate by Region | 13 |

Row 8 is a text/markdown explanation panel (no data panels). There is no standalone Quota Monitoring row — quota panels (171–174) live under Row 12 (Response Header Dims).

### tyk-gateway-fleet-health

- **UID**: `tyk-gateway-fleet-health`
- **File**: `tyk-demo/tyk-gateway-fleet-health.json`
- **Variables**: `tyk_gw_id` (multi, regex `.*`), `tyk_gw_group_id` (multi, regex `.*`)

| Row | Key Panels |
|-----|------------|
| Fleet KPIs | Gateway count (stat), Total APIs loaded (stat), Total policies loaded (stat), Fleet request rate (stat) |
| Deployment & Config State | APIs loaded per gateway (timeseries), Config drift gauge (`max - min` of `tyk_gateway_apis_loaded`), Config reloads over time |
| Go Runtime Health | Heap pressure gauge (`go_memory_used_bytes / go_memory_limit_bytes`), Heap in use vs GC goal vs limit, Goroutine fleet snapshot |
| Gateway Traffic & Load Distribution | Request rate per gateway (timeseries), Traffic distribution by gateway |
| Edge & Multi-Region | (collapsed by default) |
| Gateway Health Events | Log volume histogram by level — error/warn/info stacked bars (timeseries panel 61, w:8), Recent Gateway Errors log stream (panel 63, w:16), Upstream Failures by API table (panel 62, full width below) |

### tyk-api-portfolio

- **UID**: `tyk-api-portfolio`
- **File**: `tyk-demo/tyk-api-portfolio.json`
- **Variables**: `service_name`, `tyk_gw_group_id`, `tyk_gw_id`, `api_id` (multi, all), `method` (multi, all), `org_id` (multi, all), `slo_availability_target` (custom: 99/99.5/99.9/99.95/99.99, default 99.9), `slo_latency_ms` (custom: 200/500/1000/2000, default 500)

| Row | Key Panels |
|-----|------------|
| Portfolio KPI Bar | Total request rate, error rate, P95 latency, active API count (stat) |
| Traffic Trends | Request rate over time, traffic by API (timeseries) |
| Error Analysis | Error rate by API, error type distribution |
| API Leaderboards | Top 10 by traffic, P95 latency, error rate (bargauge) |
| Multi-Tenancy View | Traffic by org, by tenant |
| Consumer Identity | API key traffic, OAuth clients, portal app usage |
| Service Level Objectives | Availability SLO gauge, latency SLO gauge, error budget remaining, burn rate 1h / 6h, P95 vs threshold |
| Cache & Backend Intelligence | Cache hit rate, backend version distribution |

### tyk-api-troubleshooting

- **UID**: `tyk-api-troubleshooting`
- **File**: `tyk-demo/tyk-api-troubleshooting.json`
- **Variables**: `api_id` (single-select, no "All"), `tyk_gw_id` (multi), `trace_id` (textbox, default `*`)

| Row | Key Panels |
|-----|------------|
| API Health KPIs | Request rate, error rate, P95 latency, cache hit rate (stat) |
| Latency Attribution | Total/gateway/upstream latency breakdown (timeseries + pie) |
| Error Analysis | Error rate over time, response flag distribution (panel link → Loki) |
| Traffic Patterns | Traffic over time, traffic by gateway |
| Upstream Health | URS flag isolation, backend version distribution |
| Gateway Config State | APIs loaded, policies loaded for selected gateway |
| Distributed Tracing via Tempo | Recent traces table, Error traces table |
| Log Analysis | Access logs, error/warn logs, all logs with trace correlation (Loki) |

---

## 2. OTLP Metric Reference

### 4 Default Instruments (always present, unless env var overrides without re-including them)

| Prometheus Metric | Type | Key Labels |
|---|---|---|
| `http_server_request_duration_seconds` | histogram | `http_request_method`, `http_response_status_code`, `tyk_api_id`, `tyk_response_flag`, `service_name` |
| `tyk_gateway_request_duration_seconds` | histogram | `http_request_method`, `tyk_api_id`, `tyk_response_flag`, `service_name` |
| `tyk_upstream_request_duration_seconds` | histogram | `http_request_method`, `tyk_api_id`, `tyk_response_flag`, `service_name` |
| `tyk_api_requests_total` | counter | `http_request_method`, `http_response_status_code`, `tyk_api_id`, `service_name` |
| `tyk_http_requests_total` | counter | `service_name` only |

### 15 Custom Instruments

| Prometheus Metric | Source | Key Labels |
|---|---|---|
| `tyk_requests_by_route_total` | metadata | `route`, `path`, `api_id`, `api_name`, `method`, `response_code` |
| `tyk_requests_by_org_total` | metadata | `org_id`, `api_name`, `method` |
| `tyk_requests_by_version_total` | metadata | `api_version`, `api_id`, `response_code` |
| `tyk_requests_by_apikey_total` | session | `api_key_suffix`, `api_id` |
| `tyk_requests_by_oauth_total` | session | `oauth_client_id`, `api_id` |
| `tyk_requests_by_portal_total` | session | `portal_app`, `portal_org`, `api_id` |
| `tyk_requests_by_tenant_total` | header X-Tenant-ID | `tenant_id`, `api_id`, `response_code` |
| `tyk_latency_by_tenant_seconds` | header X-Tenant-ID | `tenant_id`, `api_id` |
| `tyk_requests_by_customer_total` | header X-Customer-ID | `customer_id`, `tenant_id` |
| `tyk_requests_with_cache_total` | response_header X-Cache-Status | `cache_status`, `api_id` |
| `tyk_requests_by_backend_version_total` | response_header X-Backend-Version | `backend_version`, `api_id` |
| `tyk_requests_by_content_type_total` | response_header Content-Type | `content_type`, `api_id` |
| `tyk_requests_by_tier_total` | context `tier` | `subscription_tier`, `api_id`, `response_code` |
| `tyk_latency_by_tier_seconds` | context `tier` | `subscription_tier`, `api_id` |
| `tyk_requests_by_region_total` | context `region` | `region`, `api_id` |

Histogram suffixes: `_bucket`, `_count`, `_sum`

`tyk_response_flag` values: Tyk error codes (e.g. `URS` = upstream 5xx, `BD` = bad destination) or HTTP status string (`"200"`, `"404"`) on success.

---

## 3. Dimension Sources

| Source | What it is | Valid keys |
|---|---|---|
| `metadata` | Built-in request fields, validated at startup | `method`, `response_code`, `route`, `api_id`, `api_name`, `org_id`, `response_flag`, `ip_address`, `api_version`, `host`, `scheme` |
| `session` | Auth session data, validated at startup | `api_key` (truncated last 6), `oauth_id`, `alias`, `portal_app`, `portal_org` |
| `header` | Any request header key | e.g. `X-Tenant-ID`, `X-Customer-ID` |
| `response_header` | Any response header key | e.g. `X-Cache-Status`, `Content-Type` |
| `context` | Tyk context variables (set by middleware) | e.g. `tier`, `region`, `plan` |

**Caveats:**
- `session`: only populated on authenticated requests; histograms with session labels log a warning at startup
- `response_header`: only populated on success path — errors use the `default` fallback
- `context`: requires explicit middleware (Go plugin, virtual endpoint) to set the variable
- Max 10 dimensions per instrument (OTel SDK fast path limit)
- Always specify `"default"` for header/response_header/context sources to avoid empty-label cardinality explosion

---

## 4. PromQL Patterns

### Core templates

```promql
# Counter rate
sum(rate(METRIC{service_name=~"$service_name"}[$__rate_interval]))

# Counter rate grouped by label
sum by(LABEL)(rate(METRIC{service_name=~"$service_name"}[$__rate_interval]))

# Percentile latency (seconds → ms)
histogram_quantile(0.95,
  sum by(le)(rate(METRIC_seconds_bucket{service_name=~"$service_name"}[$__rate_interval]))
) * 1000

# Percentile latency grouped by API
histogram_quantile(0.95,
  sum by(le, tyk_api_id)(rate(METRIC_seconds_bucket{service_name=~"$service_name"}[$__rate_interval]))
) * 1000

# Error rate %
sum(rate(tyk_api_requests_total{service_name=~"$service_name", http_response_status_code=~"5.."}[$__rate_interval]))
/ sum(rate(tyk_api_requests_total{service_name=~"$service_name"}[$__rate_interval])) * 100

# Top N by rate
topk(10, sum by(tyk_api_id)(rate(tyk_api_requests_total{service_name=~"$service_name"}[$__rate_interval])))

# Total over range (for pie/bar charts)
sum by(LABEL)(increase(METRIC{service_name=~"$service_name"}[$__range]))
```

### Units
- Latency panels: `* 1000` (seconds→ms), `unit: "ms"`
- Traffic panels: `unit: "reqps"`
- Error rate panels: `unit: "percent"` (0–100 scale)
- Counts: `unit: "short"`

### Time macros
- `$__rate_interval` — use for `rate()` and `histogram_quantile()` (Grafana-calculated optimal window)
- `$__range` — use for `increase()` in pie/bar charts showing totals over the selected time range

### API name join (leaderboard bargauge panels)

`tyk_requests_by_route_total` carries `api_id` (not `tyk_api_id`), so use `label_replace()` to rename it before the join. This pattern replaces raw UUID bar labels with human-readable API names.

```promql
topk(10,
  METRIC_EXPR_grouped_by_tyk_api_id
  * on(tyk_api_id) group_left(api_name)
    label_replace(
      max by(api_id, api_name)(tyk_requests_by_route_total{service_name=~"$service_name"}),
      "tyk_api_id", "$1", "api_id", "(.*)"
    )
)
```
`legendFormat: "{{api_name}}"`

Applied to: panels 22 & 33 (error rate), panel 32 (P95 latency) in `tyk-api-portfolio`. Panel 31 (request rate) already uses `tyk_requests_by_route_total` directly so only needs `legendFormat: "{{api_name}}"`.

Note: `tyk_api_id` labels are preserved on the left side of the join, so drill-down links using `${__field.labels.tyk_api_id}` continue to work.

---

## 5. Design Workflow

### Inspect the dashboard
```
mcp: get_dashboard_summary(uid="tyk-gateway-otlp-metrics")
mcp: get_dashboard_panel_queries(uid="tyk-gateway-otlp-metrics")
mcp: get_dashboard_property(uid="tyk-gateway-otlp-metrics", jsonPath="$.panels[*].title")
```

### Modify a panel (patch operation — preferred, avoids huge JSON)
```
mcp: update_dashboard(
  uid="tyk-gateway-otlp-metrics",
  operations=[
    {"op": "replace", "path": "$.panels[?(@.id==PANEL_ID)].targets[0].expr", "value": "NEW_PROMQL"},
    {"op": "replace", "path": "$.panels[?(@.id==PANEL_ID)].title", "value": "New Title"}
  ]
)
```

> **Provisioned dashboards**: `update_dashboard` via MCP returns `"Cannot save provisioned dashboard"` for dashboards 2–4. All changes must be made directly to the JSON source files under `deployments/opentelemetry-demo/src/grafana/provisioning/dashboards/tyk-demo/`. JSONPath filter syntax (`$.panels[?(@.id==N)]`) is also unsupported — use array indices (`$.panels[N]`) instead.

### Add a new panel
```
mcp: update_dashboard(
  uid="tyk-gateway-otlp-metrics",
  operations=[{"op": "add", "path": "$.panels/-", "value": { ...full panel JSON... }}]
)
```

### Render a panel image
```
mcp: get_panel_image(dashboardUid="tyk-gateway-otlp-metrics", panelId=PANEL_ID)
```

### Generate clickable panel deeplink
```
mcp: generate_deeplink(resourceType="panel", dashboardUid="tyk-gateway-otlp-metrics", panelId=PANEL_ID)
```

---

## 6. Debug Workflow

**Step 1**: Get Prometheus datasource UID
```
mcp: list_datasources(type="prometheus")
```

**Step 2**: Test the metric directly
```
mcp: query_prometheus(datasourceUid="prometheus", expr='tyk_api_requests_total', startTime="now-1h", queryType="instant")
```

**Step 3**: Check `service_name` values exist
```
mcp: list_prometheus_label_values(datasourceUid="prometheus", labelName="service_name")
# Should include "tyk-gateway"
```

**Step 4**: Verify label names match the PromQL selectors
```
mcp: list_prometheus_label_names(datasourceUid="prometheus")
mcp: list_prometheus_label_values(datasourceUid="prometheus", labelName="tyk_api_id")
```

**Step 5**: If custom metrics missing, verify env var is set and gateway has restarted (Section 8)

**Step 6**: Check for all tyk-gateway series
```
mcp: query_prometheus(datasourceUid="prometheus", expr='{service_name="tyk-gateway"}', startTime="now-5m", queryType="instant")
```

---

## 7. Common Issues & Fixes

| Symptom | Root Cause | Fix |
|---|---|---|
| Default metric panels (IDs 1–52) show "No data" | `TYK_GW_OPENTELEMETRY_METRICS_APIMETRICS` set without re-including defaults | Prepend 4 defaults to env var (Section 8) |
| All panels show "No data" | Gateway not sending OTLP / collector not running | `docker compose ps`, check otel-collector logs |
| Latency includes non-Tyk services | Missing `service_name=~"$service_name"` filter | Add filter to all PromQL exprs |
| Custom metric panels show "No data" | Env var not set or metric name typo | Check `.env` line ~39; `query_prometheus` to confirm |
| `histogram_quantile` returns `NaN` | No samples in rate window | Increase time range, generate traffic |
| Context dimension panels always show default value | Middleware not setting context variables | Context vars need explicit middleware (Go plugin, virtual endpoint) |
| `response_header` labels are empty/default on errors | Error path doesn't populate response headers | By design; use `"default"` to handle gracefully |
| "Value" legend on Status Code Distribution (id=23) | `instant: true, format: "table"` ignores legendFormat | Add `"displayName": "Requests"` to `fieldConfig.defaults` |
| Loki `count_over_time` metric query returns no data for gateway logs | `{service_name="tyk-gateway"}` matches 0 indexed streams — all logs share one stream, `service_name` is structured metadata (unindexed) | Use `{service_name=~".+"}` as stream selector, then `\| service_name="tyk-gateway"` as post-filter |
| Loki metric bar chart shows gaps at wider time ranges | Hardcoded `[5m]` window in `count_over_time` — when Grafana step > 5m, buckets don't cover the full step | Replace `[5m]` with `[$__interval]` |

---

## 8. Environment Variable Configuration

**File**: `.env` (project root, tyk-demo), line ~39
**Variable**: `TYK_GW_OPENTELEMETRY_METRICS_APIMETRICS`

**Critical rule**: Setting this variable **replaces** all defaults. Always prepend all 4 default instruments first.

### Instrument schema
```json
{
  "name": "tyk.requests.by.route",
  "type": "counter",
  "description": "...",
  "histogram_source": "total",
  "dimensions": [
    {
      "source": "metadata",
      "key": "route",
      "label": "route",
      "default": "unknown"
    }
  ]
}
```

**Naming rules**:
- Counter → Prometheus: `metric_name_total` (unit hardcoded `"1"`)
- Histogram → Prometheus: `metric_name_seconds_{bucket,count,sum}` (unit hardcoded `"s"`)
- `service_name` is auto-promoted by Prometheus OTLP receiver from `service.name` resource attribute — not a configurable dimension
- OTel name dots become underscores: `tyk.requests.by.route` → `tyk_requests_by_route_total`

**Total instruments**: 19 (4 defaults + 15 custom)
**Gateway source**: `internal/otel/apimetrics/registry.go` (lines 73, 84), `defaults.go`

---

## 9. Dashboard Variables

| Variable | Type | Query / Source |
|---|---|---|
| `datasource_prometheus` | datasource | type: `prometheus` |
| `service_name` | query | `label_values(tyk_api_requests_total, service_name)` — default: `tyk-gateway` |
| `api_id` | query (multi, all) | `label_values(tyk_api_requests_total{service_name=~"$service_name"}, tyk_api_id)` |
| `method` | query (multi, all) | `label_values(tyk_api_requests_total{service_name=~"$service_name"}, http_request_method)` |
| `org_id` | query (multi, all) | `label_values(tyk_requests_by_org_total{service_name=~"$service_name"}, org_id)` |
| `tenant_id` | query (multi, all) | `label_values(tyk_requests_by_tenant_total{service_name=~"$service_name"}, tenant_id)` |

**Why `service_name` is critical**: The OTel collector receives OTLP from 20+ demo services (frontend, checkout, etc.). `http_server_request_duration_seconds` is a standard OTel semantic convention metric emitted by many services. Without the filter, latency queries aggregate across all services.

---

## 10. MCP Tool Quick Reference

| Task | Tool | Key Parameters |
|---|---|---|
| Find Prometheus datasource UID | `list_datasources` | `type="prometheus"` |
| Run a PromQL query | `query_prometheus` | `datasourceUid`, `expr`, `startTime`, `queryType` |
| Browse metric names | `list_prometheus_metric_names` | `datasourceUid`, `regex` |
| Check label values | `list_prometheus_label_values` | `datasourceUid`, `labelName` |
| Dashboard overview | `get_dashboard_summary` | `uid=` any of: `tyk-gateway-otlp-metrics`, `tyk-gateway-fleet-health`, `tyk-api-portfolio`, `tyk-api-troubleshooting` |
| See all panel queries | `get_dashboard_panel_queries` | `uid=` (any dashboard UID above) |
| Get full dashboard JSON | `get_dashboard_by_uid` | `uid=` (any dashboard UID above) |
| Query specific JSON paths | `get_dashboard_property` | `uid`, `jsonPath` (e.g. `$.panels[*].title`) |
| Patch panel(s) | `update_dashboard` with `operations` | `uid`, array of patch ops with JSONPath |
| Add a panel | `update_dashboard` | `op: "add", path: "$.panels/-"`, full panel JSON as `value` |
| Render panel to PNG | `get_panel_image` | `dashboardUid`, `panelId` |
| Create clickable panel link | `generate_deeplink` | `resourceType="panel"`, `dashboardUid`, `panelId` |
| Search dashboards | `search_dashboards` | `query="tyk"` |
| Find Loki datasource UID | `list_datasources` | `type="loki"` |
| Query Loki logs | `query_loki_logs` | `datasourceUid`, `logql`, `startRfc3339` |
| Find Tempo datasource UID | `list_datasources` | `type="tempo"` |

---

## 11. Fleet Health — Metrics & Queries

### Key Prometheus Metrics (not in tyk-gateway-otlp-metrics)

| Metric | Type | Key Labels |
|--------|------|------------|
| `tyk_gateway_apis_loaded` | gauge | `tyk_gw_id`, `tyk_gw_group_id` |
| `tyk_gateway_policies_loaded` | gauge | `tyk_gw_id`, `tyk_gw_group_id` |
| `tyk_gateway_config_reload_total` | counter | `tyk_gw_id` |
| `tyk_gateway_config_reload_duration_seconds` | histogram | `tyk_gw_id` |
| `go_memory_used_bytes` | gauge | `tyk_gw_id` |
| `go_memory_gc_goal_bytes` | gauge | `tyk_gw_id` |
| `go_memory_limit_bytes` | gauge | `tyk_gw_id` |
| `go_goroutine_count` | gauge | `tyk_gw_id` |
| `go_processor_limit` | gauge | `tyk_gw_id` |
| `go_memory_allocated_bytes_total` | counter | `tyk_gw_id` |
| `go_memory_allocations_total` | counter | `tyk_gw_id` |

`tyk_http_requests_total` and `tyk_api_requests_total` also appear here with `tyk_gw_id` label for per-gateway traffic.

### Key PromQL Patterns

```promql
# Config drift: difference in APIs loaded across gateways
max(tyk_gateway_apis_loaded{tyk_gw_id=~"$tyk_gw_id"}) - min(tyk_gateway_apis_loaded{tyk_gw_id=~"$tyk_gw_id"})

# Heap pressure (0–1 scale, > 0.8 is concerning)
go_memory_used_bytes{tyk_gw_id=~"$tyk_gw_id"} / go_memory_limit_bytes{tyk_gw_id=~"$tyk_gw_id"}

# Per-gateway request rate
sum by(tyk_gw_id)(rate(tyk_http_requests_total{tyk_gw_id=~"$tyk_gw_id"}[$__rate_interval]))

# Config reload rate
rate(tyk_gateway_config_reload_total{tyk_gw_id=~"$tyk_gw_id"}[$__rate_interval])
```

### Loki Queries (Gateway Health Events row)

```logql
# Gateway error logs — log panel (full-scan, works fine with unindexed service_name)
{service_name="tyk-gateway"} | detected_level=~`error|fatal`

# Log volume metric query — count_over_time for timeseries bar chart (panel 61)
# IMPORTANT: {service_name="tyk-gateway"} returns 0 indexed streams in this deployment.
# detected_level is structured metadata (unindexed). Use the actual single indexed stream:
sum(count_over_time({service_name=~".+"} | service_name="tyk-gateway" | detected_level="error" [$__interval]))
# Use separate refIds per level (error/warn/info) for stacked bars with per-series color overrides.
# Stacked bar config: drawStyle="bars", stacking={mode:"normal"}, fillOpacity=80

# Upstream failures
{service_name="tyk-gateway"} | tyk_prefix=`access-log` | tyk_response_flag=~`URS|UT|UH`
```

---

## 12. API Portfolio — SLO Patterns & Variables

### SLO Variables

| Variable | Type | Options / Source |
|----------|------|-----------------|
| `slo_availability_target` | custom | `99,99.5,99.9,99.95,99.99` (default: 99.9) |
| `slo_latency_ms` | custom | `200,500,1000,2000` (default: 500) |

Both are used as raw numbers in PromQL via `$slo_availability_target` and `$slo_latency_ms`.

### SLO PromQL Patterns

```promql
# Availability % (current window)
(1 - (
  sum(rate(tyk_api_requests_total{service_name=~"$service_name", http_response_status_code=~"5.."}[$__rate_interval]))
  / sum(rate(tyk_api_requests_total{service_name=~"$service_name"}[$__rate_interval]))
)) * 100

# Error budget remaining % (30-day window)
(1 - (
  sum(increase(tyk_api_requests_total{service_name=~"$service_name", http_response_status_code=~"5.."}[30d]))
  / sum(increase(tyk_api_requests_total{service_name=~"$service_name"}[30d]))
)) / (1 - $slo_availability_target / 100) * 100

# SLO burn rate — 1h (how fast error budget is consumed vs allowed)
(
  sum(rate(tyk_api_requests_total{service_name=~"$service_name", http_response_status_code=~"5.."}[1h]))
  / sum(rate(tyk_api_requests_total{service_name=~"$service_name"}[1h]))
) / (1 - $slo_availability_target / 100)

# P95 latency vs SLO threshold (for gauge: green if <= $slo_latency_ms)
histogram_quantile(0.95,
  sum by(le)(rate(http_server_request_duration_seconds_bucket{service_name=~"$service_name"}[$__rate_interval]))
) * 1000
```

### Cross-Dashboard Links

Panels in API Portfolio use `links` with URL templates to deep-link into API Troubleshooting:
```
/grafana/d/tyk-api-troubleshooting?var-api_id=${__data.fields.tyk_api_id}
```
This allows clicking an API row in a leaderboard to jump directly to that API's troubleshooting view.

---

## 13. API Troubleshooting — Tempo & Loki Patterns

### Tempo Query Pattern (traceqlSearch)

Both Tempo panels use `queryType: "traceqlSearch"` with structured filters:

```
# Recent traces for a specific API
service.name = "tyk-gateway"    (resource scope)
tyk.api.id = "$api_id"          (span scope)

# Error traces only — add:
status = error                   (intrinsic scope)
```

In Grafana panel JSON, these appear as `filters` objects in the `targets[].query` field:
```json
{
  "filters": [
    {"id": "...", "scope": "resource", "tag": "service.name", "operator": "=", "value": "tyk-gateway", "valueType": "string"},
    {"id": "...", "scope": "span", "tag": "tyk.api.id", "operator": "=", "value": "$api_id", "valueType": "string"}
  ]
}
```

The `trace_id` variable (textbox, default `*`) is used to filter to a specific trace in the Log Analysis row — Loki panels include a `tyk_trace_id=~"$trace_id"` filter for drill-down correlation.

### Loki Query Patterns

```logql
# API access logs for selected API
{service_name="tyk-gateway"} | tyk_prefix=`access-log` | tyk_api_id=`$api_id`

# Error and warning logs
{service_name="tyk-gateway"} | detected_level=~`error|warn|fatal`

# 5xx failures for selected API
{service_name="tyk-gateway"} | tyk_prefix=`access-log` | tyk_api_id=`$api_id` | tyk_status=~`5..`

# All logs with trace correlation (using trace_id variable)
{service_name="tyk-gateway"} | tyk_api_id=`$api_id` | tyk_trace_id=~`$trace_id`
```

### Upstream Health — Response Flags

The Upstream Health row isolates upstream-related response flags. Key flags used as filters:

| Flag | Meaning |
|------|---------|
| `URS` | Upstream returned 5xx |
| `UT` | Upstream timeout |
| `UH` | No healthy upstream |
| `BD` | Bad destination / connection refused |

Pattern for isolating upstream failures:
```promql
sum by(tyk_response_flag)(
  rate(http_server_request_duration_seconds_count{
    service_name=~"$service_name",
    tyk_api_id=~"$api_id",
    tyk_response_flag=~"URS|UT|UH|BD"
  }[$__rate_interval])
)
```

---

## 14. Dashboard Navigation (Cross-Links)

Dashboards 2, 3, and 4 each carry a `links` array at the dashboard level (not panel level) that renders as clickable navigation buttons in the Grafana toolbar.

### Structure (in dashboard JSON)

```json
"links": [
  {
    "title": "Fleet Health",
    "type": "link",
    "url": "/grafana/d/tyk-gateway-fleet-health",
    "targetBlank": false,
    "icon": "external link"
  },
  {
    "title": "API Portfolio",
    "type": "link",
    "url": "/grafana/d/tyk-api-portfolio",
    "targetBlank": false,
    "icon": "external link"
  },
  {
    "title": "API Troubleshooting",
    "type": "link",
    "url": "/grafana/d/tyk-api-troubleshooting",
    "targetBlank": false,
    "icon": "external link"
  }
]
```

Each dashboard omits its own UID from its `links` array (no self-links).

### Inspect or modify nav links via MCP

```
mcp: get_dashboard_property(uid="tyk-gateway-fleet-health", jsonPath="$.links")
mcp: update_dashboard(uid="tyk-gateway-fleet-health", operations=[
  {"op": "replace", "path": "$.links[0].title", "value": "New Title"}
])
```

### Adding nav links to tyk-gateway-otlp-metrics

The OTLP metrics dashboard (in `tyk-demo-backup/`) does not currently have nav links. To add them:
```
mcp: update_dashboard(uid="tyk-gateway-otlp-metrics", operations=[
  {"op": "add", "path": "$.links/-", "value": {
    "title": "Fleet Health", "type": "link",
    "url": "/grafana/d/tyk-gateway-fleet-health", "targetBlank": false, "icon": "external link"
  }}
])
```
