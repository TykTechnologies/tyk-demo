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

The following environment variables are used by this deployment.

Please include these in your `.env` file.

```sh
INSTRUMENTATION_ENABLED=0
OPENTELEMETRY_ENABLED=true
OPENTELEMETRY_ENDPOINT=otel-collector:4317
GATEWAY_IMAGE_REPO=tyk-gateway-ee
TYK_GW_LOGFORMAT=json
TYK_GW_LOGLEVEL=warn
TYK_GW_OPENTELEMETRY_RESOURCENAME=tyk-gateway
TYK_GW_OPENTELEMETRY_SAMPLING_TYPE=TraceIDRatioBased
TYK_GW_OPENTELEMETRY_SAMPLING_RATE=0.5
TYK_GW_ACCESSLOGS_ENABLED=true
TYK_GW_PROMETHEUS_ENABLED=true
TYK_GW_PROMETHEUS_LISTENADDRESS=:9090
TYK_GW_PROMETHEUS_PATH=/metrics
TYK_GW_PROMETHEUS_METRICPREFIX=tyk_gateway
TYK_GW_PROMETHEUS_ENABLEGOCOLLECTOR=true
TYK_GW_PROMETHEUS_ENABLEPROCESSCOLLECTOR=true
TYK_GW_PROMETHEUS_ENABLEPERAPIMETRICS=false

TYK_GW_ENABLECONFIGINSPECTION=true

# Otel Metrics
TYK_GW_OPENTELEMETRY_METRICS_ENABLED=true
TYK_GW_OPENTELEMETRY_METRICS_EXPORTINTERVAL=5
TYK_GW_OPENTELEMETRY_METRICS_APIMETRICS=[{"name":"http.server.request.duration","type":"histogram","description":"End-to-end request latency","histogram_source":"total","dimensions":[{"source":"metadata","key":"method","label":"http.request.method"},{"source":"metadata","key":"response_code","label":"http.response.status_code"},{"source":"metadata","key":"api_id","label":"tyk.api.id"},{"source":"metadata","key":"response_flag","label":"tyk.response_flag"}]},{"name":"tyk.gateway.request.duration","type":"histogram","description":"Gateway processing time","histogram_source":"gateway","dimensions":[{"source":"metadata","key":"method","label":"http.request.method"},{"source":"metadata","key":"api_id","label":"tyk.api.id"},{"source":"metadata","key":"response_flag","label":"tyk.response_flag"}]},{"name":"tyk.upstream.request.duration","type":"histogram","description":"Upstream response time","histogram_source":"upstream","dimensions":[{"source":"metadata","key":"method","label":"http.request.method"},{"source":"metadata","key":"api_id","label":"tyk.api.id"},{"source":"metadata","key":"response_flag","label":"tyk.response_flag"}]},{"name":"tyk.api.requests.total","type":"counter","description":"Request count with identity dimensions","dimensions":[{"source":"metadata","key":"method","label":"http.request.method"},{"source":"metadata","key":"response_code","label":"http.response.status_code"},{"source":"metadata","key":"api_id","label":"tyk.api.id"}]},{"name":"tyk.requests.by.route","type":"counter","description":"Request count by route path and API name (metadata)","dimensions":[{"source":"metadata","key":"route","label":"route"},{"source":"metadata","key":"api_id","label":"api_id"},{"source":"metadata","key":"api_name","label":"api_name"},{"source":"metadata","key":"method","label":"method"},{"source":"metadata","key":"response_code","label":"response_code"},{"source":"metadata","key":"scheme","label":"scheme","default":"http"}]},{"name":"tyk.requests.by.org","type":"counter","description":"Request count per organization (metadata)","dimensions":[{"source":"metadata","key":"org_id","label":"org_id"},{"source":"metadata","key":"api_id","label":"api_id"},{"source":"metadata","key":"api_name","label":"api_name"},{"source":"metadata","key":"method","label":"method"}]},{"name":"tyk.requests.by.version","type":"counter","description":"Request count per API version (metadata)","dimensions":[{"source":"metadata","key":"api_version","label":"api_version"},{"source":"metadata","key":"api_id","label":"api_id"},{"source":"metadata","key":"response_code","label":"response_code"}]},{"name":"tyk.requests.by.apikey","type":"counter","description":"Request count per API key suffix - last 6 chars (session)","dimensions":[{"source":"session","key":"api_key","label":"api_key_suffix"},{"source":"metadata","key":"api_id","label":"api_id"}]},{"name":"tyk.requests.by.oauth","type":"counter","description":"Request count per OAuth client ID (session)","dimensions":[{"source":"session","key":"oauth_id","label":"oauth_client_id"},{"source":"metadata","key":"api_id","label":"api_id"},{"source":"metadata","key":"response_code","label":"response_code"}]},{"name":"tyk.requests.by.portal","type":"counter","description":"Request count per developer portal app and org (session)","dimensions":[{"source":"session","key":"portal_app","label":"portal_app"},{"source":"session","key":"portal_org","label":"portal_org"},{"source":"metadata","key":"api_id","label":"api_id"}]},{"name":"tyk.requests.by.tenant","type":"counter","description":"Request count per tenant from X-Tenant-ID request header","dimensions":[{"source":"header","key":"X-Tenant-ID","label":"tenant_id","default":"unknown"},{"source":"metadata","key":"api_id","label":"api_id"},{"source":"metadata","key":"response_code","label":"response_code"}]},{"name":"tyk.latency.by.tenant","type":"histogram","description":"End-to-end latency per tenant from X-Tenant-ID request header","histogram_source":"total","dimensions":[{"source":"header","key":"X-Tenant-ID","label":"tenant_id","default":"unknown"},{"source":"metadata","key":"api_id","label":"api_id"}]},{"name":"tyk.requests.by.customer","type":"counter","description":"Request count per customer from X-Customer-ID request header","dimensions":[{"source":"header","key":"X-Customer-ID","label":"customer_id","default":"unknown"},{"source":"header","key":"X-Tenant-ID","label":"tenant_id","default":"unknown"}]},{"name":"tyk.requests.with.cache","type":"counter","description":"Request count by cache status from X-Tyk-Cached-Response response header","dimensions":[{"source":"response_header","key":"X-Tyk-Cached-Response","label":"cache_status","default":"0"},{"source":"metadata","key":"api_id","label":"api_id"}]},{"name":"tyk.requests.by.backend.version","type":"counter","description":"Request count by backend version from X-Backend-Version response header","dimensions":[{"source":"response_header","key":"X-Backend-Version","label":"backend_version","default":"unknown"},{"source":"metadata","key":"api_id","label":"api_id"}]},{"name":"tyk.requests.by.content.type","type":"counter","description":"Request count by Content-Type response header","dimensions":[{"source":"response_header","key":"Content-Type","label":"content_type","default":"unknown"},{"source":"metadata","key":"api_id","label":"api_id"}]},{"name":"tyk.requests.by.tier","type":"counter","description":"Request count per subscription tier from context variable","dimensions":[{"source":"context","key":"tier","label":"subscription_tier","default":"standard"},{"source":"metadata","key":"api_id","label":"api_id"},{"source":"metadata","key":"response_code","label":"response_code"}]},{"name":"tyk.latency.by.tier","type":"histogram","description":"End-to-end latency per subscription tier from context variable","histogram_source":"total","dimensions":[{"source":"context","key":"tier","label":"subscription_tier","default":"standard"},{"source":"metadata","key":"api_id","label":"api_id"}]},{"name":"tyk.requests.by.region","type":"counter","description":"Request count per region from context variable","dimensions":[{"source":"context","key":"region","label":"region","default":"unknown"},{"source":"metadata","key":"api_id","label":"api_id"}]},{"name":"tyk.requests.by.quota_limit","type":"counter","description":"Request count per quota tier, from X-RateLimit-Limit response header (quota ceiling, not per-second rate limit)","dimensions":[{"source":"response_header","key":"X-RateLimit-Limit","label":"quota_limit","default":"0"},{"source":"metadata","key":"api_id","label":"api_id"}]}]

# Demo App version
IMAGE_VERSION=2.1.3
OTEL_DEMO_IMAGE_NAME=ghcr.io/open-telemetry/demo
OTEL_DEMO_DEMO_VERSION=2.1.3

# Build Args
TRACETEST_IMAGE_VERSION=v1.7.1
OTEL_JAVA_AGENT_VERSION=2.21.0
OPENTELEMETRY_CPP_VERSION=1.23.0

# Dependent images
COLLECTOR_CONTRIB_IMAGE=ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.133.0
FLAGD_IMAGE=ghcr.io/open-feature/flagd:v0.12.8
GRAFANA_IMAGE=grafana/grafana:12.2.0
JAEGERTRACING_IMAGE=jaegertracing/jaeger:2.10.0
# must also update version field in src/grafana/provisioning/datasources/opensearch.yaml
OPENSEARCH_IMAGE=opensearchproject/opensearch:3.2.0
OPENSEARCH_DOCKERFILE=./deployments/opentelemetry-demo/src/opensearch/Dockerfile
LOKI_IMAGE=grafana/loki:3.5.0
POSTGRES_IMAGE=postgres:17.6 # used only for TraceTest
PROMETHEUS_IMAGE=quay.io/prometheus/prometheus:v3.5.0
VALKEY_IMAGE=valkey/valkey:8.1.3-alpine
TRACETEST_IMAGE=kubeshop/tracetest:${TRACETEST_IMAGE_VERSION}

# Demo Platform
ENV_PLATFORM=local

# IPv6 Flag control
IPV6_ENABLED=false

# OpenTelemetry Collector
HOST_FILESYSTEM=/
DOCKER_SOCK=/var/run/docker.sock
OTEL_COLLECTOR_HOST=otel-collector
OTEL_COLLECTOR_PORT_GRPC=4317
OTEL_COLLECTOR_PORT_HTTP=4318
OTEL_COLLECTOR_CONFIG=./deployments/opentelemetry-demo/src/otel-collector/otelcol-config.yml
OTEL_COLLECTOR_CONFIG_EXTRAS=./deployments/opentelemetry-demo/src/otel-collector/otelcol-config-extras.yml
OTEL_EXPORTER_OTLP_ENDPOINT=http://${OTEL_COLLECTOR_HOST}:${OTEL_COLLECTOR_PORT_GRPC}
PUBLIC_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:8085/otlp-http/v1/traces

# OpenTelemetry Resource Definitions
OTEL_RESOURCE_ATTRIBUTES=service.namespace=opentelemetry-demo,service.version=${IMAGE_VERSION}

# Metrics Temporality
OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative

# ******************
# Core Demo Services
# ******************
# Accounting Service
ACCOUNTING_DOCKERFILE=./deployments/opentelemetry-demo/src/accounting/Dockerfile

# Ad Service
AD_PORT=9555
AD_ADDR=ad:${AD_PORT}
AD_DOCKERFILE=./deployments/opentelemetry-demo/src/ad/Dockerfile

# Cart Service
CART_PORT=7070
CART_ADDR=cart:${CART_PORT}
CART_DOCKERFILE=./deployments/opentelemetry-demo/src/cart/src/Dockerfile

# Checkout Service
CHECKOUT_PORT=5050
CHECKOUT_ADDR=checkout:${CHECKOUT_PORT}
CHECKOUT_DOCKERFILE=./deployments/opentelemetry-demo/src/checkout/Dockerfile

# Currency Service
CURRENCY_PORT=7001
CURRENCY_ADDR=currency:${CURRENCY_PORT}
CURRENCY_DOCKERFILE=./deployments/opentelemetry-demo/src/currency/Dockerfile

# Email Service
EMAIL_PORT=6060
EMAIL_ADDR=http://email:${EMAIL_PORT}
EMAIL_DOCKERFILE=./deployments/opentelemetry-demo/src/email/Dockerfile

# Fraud Service
FRAUD_DOCKERFILE=./deployments/opentelemetry-demo/src/fraud-detection/Dockerfile

# Frontend
FRONTEND_PORT=8082
FRONTEND_ADDR=frontend:${FRONTEND_PORT}
FRONTEND_URL=http://${FRONTEND_ADDR}
FRONTEND_DOCKERFILE=./deployments/opentelemetry-demo/src/frontend/Dockerfile

# Frontend Proxy (Envoy)
ENVOY_ADDR=0.0.0.0
ENVOY_PORT=8085
ENVOY_ADMIN_PORT=10000
FRONTEND_HOST=frontend
FRONTEND_PROXY_ADDR=frontend-proxy:${ENVOY_PORT}
FRONTEND_PROXY_DOCKERFILE=./deployments/opentelemetry-demo/src/frontend-proxy/Dockerfile

# Image Provider
IMAGE_PROVIDER_HOST=image-provider
IMAGE_PROVIDER_PORT=8081
IMAGE_PROVIDER_DOCKERFILE=./deployments/opentelemetry-demo/src/image-provider/Dockerfile

# Load Generator
LOCUST_WEB_PORT=8089
LOCUST_USERS=5
LOCUST_HOST=http://${FRONTEND_PROXY_ADDR}
LOCUST_WEB_HOST=load-generator
LOCUST_AUTOSTART=true
LOCUST_HEADLESS=false
LOAD_GENERATOR_DOCKERFILE=./deployments/opentelemetry-demo/src/load-generator/Dockerfile

# Payment Service
PAYMENT_PORT=50051
PAYMENT_ADDR=payment:${PAYMENT_PORT}
PAYMENT_DOCKERFILE=./deployments/opentelemetry-demo/src/payment/Dockerfile

# Product Catalog Service
PRODUCT_CATALOG_RELOAD_INTERVAL=10
PRODUCT_CATALOG_PORT=3550
PRODUCT_CATALOG_ADDR=product-catalog:${PRODUCT_CATALOG_PORT}
PRODUCT_CATALOG_DOCKERFILE=./deployments/opentelemetry-demo/src/product-catalog/Dockerfile

# Quote Service
QUOTE_PORT=8090
QUOTE_ADDR=http://quote:${QUOTE_PORT}
QUOTE_DOCKERFILE=./deployments/opentelemetry-demo/src/quote/Dockerfile

# Recommendation Service
RECOMMENDATION_PORT=9001
RECOMMENDATION_ADDR=recommendation:${RECOMMENDATION_PORT}
RECOMMENDATION_DOCKERFILE=./deployments/opentelemetry-demo/src/recommendation/Dockerfile

# Shipping Service
SHIPPING_PORT=50050
SHIPPING_ADDR=http://shipping:${SHIPPING_PORT}
SHIPPING_DOCKERFILE=./deployments/opentelemetry-demo/src/shipping/Dockerfile

# ******************
# Dependent Services
# ******************
# Flagd
FLAGD_HOST=flagd
FLAGD_PORT=8013
FLAGD_OFREP_PORT=8016

# Flagd UI
FLAGD_UI_HOST=flagd-ui
FLAGD_UI_PORT=4000
FLAGD_UI_DOCKERFILE=./deployments/opentelemetry-demo/src/flagd-ui/Dockerfile

# Kafka
KAFKA_PORT=9092
KAFKA_HOST=kafka
KAFKA_ADDR=${KAFKA_HOST}:${KAFKA_PORT}
# KAFKA_DOCKERFILE=./deployments/opentelemetry-demo/src/kafka/Dockerfile

# Valkey
VALKEY_PORT=6379
VALKEY_ADDR=valkey-cart:${VALKEY_PORT}

# Postgres
POSTGRES_HOST=postgresql
POSTGRES_PORT=5432
POSTGRES_DB=otel
POSTGRES_PASSWORD=otel
POSTGRES_DOCKERFILE=./deployments/opentelemetry-demo/src/postgres/Dockerfile

# ********************
# Telemetry Components
# ********************
# Grafana
GRAFANA_PORT=3000
GRAFANA_HOST=grafana

# Jaeger
JAEGER_HOST=jaeger
JAEGER_UI_PORT=16686
JAEGER_GRPC_PORT=4317

# Tempo
TEMPO_IMAGE=grafana/tempo:2.7.2
TEMPO_HOST=tempo
TEMPO_HTTP_PORT=3200

# Prometheus
PROMETHEUS_PORT=9090
PROMETHEUS_HOST=prometheus
PROMETHEUS_ADDR=${PROMETHEUS_HOST}:${PROMETHEUS_PORT}
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