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
GATEWAY_VERSION=v5.9.2
GATEWAY2_VERSION=v5.9.2
DASHBOARD_VERSION=v5.9.2
MDCB_VERSION=v2.8.6
PUMP_VERSION=v1.12.0
PUMP_CONFIG=./deployments/opentelemetry-demo/volumes/tyk-pump/pump.conf
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

# Prometheus
PROMETHEUS_PORT=9090
PROMETHEUS_HOST=prometheus
PROMETHEUS_ADDR=${PROMETHEUS_HOST}:${PROMETHEUS_PORT}
```

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