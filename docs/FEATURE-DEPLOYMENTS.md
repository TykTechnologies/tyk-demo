# Feature Deployments

This document provides a comprehensive list of all available feature deployments in Tyk Demo. Each deployment extends the base functionality with specific Tyk capabilities.

## Available Feature Deployments

Below is a list of the available feature deployments:

| Feature Deployment | Description | Requirements |
|-------------------|-------------|-------------|
| [Analytics to Datadog](../deployments/analytics-datadog/README.md) | Export analytics data to Datadog for monitoring and visualization | Datadog account |
| [Analytics to Kibana](../deployments/analytics-kibana/README.md) | Export analytics data to Kibana for log analysis and visualization | None |
| [Analytics to Splunk](../deployments/analytics-splunk/README.md) | Export analytics data to Splunk for advanced analytics and monitoring | None |
| [Bench test suite](../deployments/bench/README.md) | Run performance and load testing for Tyk deployments | None |
| [CI/CD with Jenkins](../deployments/cicd/README.md) | Integrate Tyk with Jenkins for continuous integration and deployment | None |
| [PostgreSQL database](../deployments/database-postgres/README.md) | Migrate from MongoDB to PostgreSQL | None |
| [Federation](../deployments/federation/README.md) | Enable multi-region or multi-cloud API management with Tyk Federation | None |
| [Healthcheck Blackbox](../deployments/healthcheck-blackbox/README.md) | Monitor Tyk system health using Prometheus and Blackbox Exporter | None |
| [Instrumentation](../deployments/instrumentation/README.md) | Add instrumentation for monitoring and debugging | None |
| [Kubernetes Operator](../deployments/k8s-operator/README.md) | Use the Tyk K8s Operator to configure the Dashboard | Kubernetes |
| [Keycloak](../deployments/keycloak-dcr/README.md) | Integrate with Keycloak for dynamic client registration | None |
| [Nginx Load Balancer](../deployments/load-balancer-nginx/README.md) | Use Nginx to load balance Tyk Gateways | None |
| [Mail server](../deployments/mailserver/README.md) | Set up a mail server for email notifications and testing | None |
| [MDCB](../deployments/mdcb/README.md) | Deploy Multi-Data Center Bridge for distributed API management | MDCB license |
| [MQTT](../deployments/mqtt/README.md) | Enable MQTT protocol support for IoT use cases | None |
| [OpenTelemetry with Jaeger](../deployments/otel-jaeger/README.md) | Use OpenTelemetry with Jaeger for distributed tracing | None |
| [OpenTelemetry with New Relic](../deployments/otel-new-relic/README.md) | Use OpenTelemetry with New Relic for distributed tracing | New Relic account |
| [Python gRPC server](../deployments/plugin-grpc-python/README.md) | Example deployment of a Python-based gRPC plugin server | None |
| [Enterprise Portal](../deployments/portal/README.md) | Deploy the Tyk Enterprise Developer Portal | Enterprise license |
| [SLIs with Prometheus/Grafana](../deployments/slo-prometheus-grafana/README.md) | Monitor Service Level Indicators and Objectives with Prometheus and Grafana | None |
| [Single Sign-On](../deployments/sso/README.md) | Enable Single Sign-On for Tyk Dashboard and Portal | None |
| [Subscriptions](../deployments/subscriptions/README.md) | Use GraphQL to service websocket subscriptions | None |
| [Tyk 2](../deployments/tyk2/README.md) | Add a second Tyk environment | None |
| [Unikernel Unikraft](../deployments/unikernel-unikraft/README.md) | Deploy the Tyk Gateway as a unikernel | Unikraft account |
| [WAF](../deployments/waf/README.md) | Add Web Application Firewall capabilities to your deployment | None |

## Deploying Features

To deploy a feature, use the `up.sh` script followed by the feature name:

```bash
./up.sh feature-name
```

Example:
```bash
./up.sh analytics-kibana
```

You can also deploy multiple features at once:

```bash
./up.sh analytics-kibana instrumentation sso
```

> **Note:** Ensure your system has sufficient Docker resources when deploying multiple features simultaneously.

## Combining Features

Most feature deployments can be combined with others. When features are combined:

1. All required containers for each feature are started
2. Bootstrap scripts for each feature are executed
3. Integration points between features are automatically configured when applicable

## Feature-Specific Documentation

Each feature deployment includes its own `README.md`, which contains::
- Detailed description of the feature
- Specific setup instructions
- Usage examples
- Postman collections (when available)
- Additional requirements
- Troubleshooting information

Refer to the individual deployment READMEs for comprehensive information about each feature.