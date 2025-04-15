# Detailed Setup Guide

This guide provides comprehensive instructions for setting up and running the Tyk Demo environment. It’s aimed at technical users who want to understand what’s happening under the hood or customise their setup.

## 1. Clone the Repository

Clone the Tyk Demo repository to your local machine:

```bash
git clone https://github.com/TykTechnologies/tyk-demo.git
cd tyk-demo
```

## 2. Configure Local DNS (hosts file)

For local domains (like dashboard.localhost or gateway.localhost) to resolve correctly, you’ll need to add entries to your system’s `/etc/hosts` file:

Run the helper script:

```bash
sudo ./scripts/update-hosts.sh
```

This will add entries such as:

```bash
127.0.0.1       tyk-gateway.localhost
127.0.0.1       tyk-dashboard.localhost
```

> **Note:** You may be prompted for your password due to the use of `sudo`.

## 3. Configure Tyk Licence

Tyk Demo uses an `.env` file to manage environment-specific settings (such as your licence key).

Run the `update-env.sh` script to add your licence key to the environment file. Replace `YOUR_LICENCE_KEY` with your actual licence key:

```bash
./scripts/update-env.sh DASHBOARD_LICENCE YOUR_LICENCE_KEY
```

If you also have an MDCB licence, that can be similarly set:

```bash
./scripts/update-env.sh MDCB_LICENCE YOUR_MDCB_LICENCE_KEY
```

These values will now be set in the `.env` file.

## 4. Start the Demo Environment

To spin up the base environment:

```bash
./up.sh
```

This command:
- Brings up all required services using Docker Compose
- Boots Tyk Gateway, Dashboard, and supporting services
- Waits until services are fully initialised
- Applies bootstrap configurations (users, organisations, APIs, etc.)

On the first run, the Go plugins will be built. This can take 5–10 minutes or longer, depending on your system’s performance. The build is cached for future runs, based on the version of Tyk you are using. To skip building the plugins, use the `--skip-plugin-build` flag, but any functionality that depends on Go plugins could be affected.

You’ll know the setup is complete when you see a list of Services with URLs and login credentials, follow by:

```bash
Tyk Demo initialisation process completed
```

## 5. Explore the Environment

The main Tyk services are accessible through these URLs:

| Service      | URL                                   | Notes                          |
|--------------|---------------------------------------|--------------------------------|
| Dashboard    | [http://tyk-dashboard.localhost:3000](http://tyk-dashboard.localhost:3000) | Dashboard UI/API |
| Gateway      | [http://tyk-gateway.localhost:8080](http://tyk-gateway.localhost:8080) | Primary gateway |
| Gateway 2    | [http://tyk-gateway-2.localhost:8081](http://tyk-gateway-2.localhost:8081) | Secondary gateway (segmented) |
| MongoDB      | [mongodb://localhost:27017](mongodb://localhost:27017) | Dashboard database |
| Redis        | [redis://localhost:6379](redis://localhost:6379) | Gateway database |

Feature deployments may make additional services available.

## 6. Import Postman Collection (Optional)

A ready-made Postman collection is available to explore key Tyk workflows:

1. Open Postman

2. Import the file `deployments/tyk/tyk_demo_tyk.postman_collection.json`

This collection contains a wide range of examples, including:
- **Authentication**: Bearer, JWT, Basic, OAuth, mTLS, Custom
- **Traffic Control**: Rate limiting, quotas, throttling
- **Middleware**: Mock response, body transform, enforced timeout, URL rewrite, caching
- **Versioning**: Header-based, path-based, expiry
- **Advanced Options**: Webhooks, context variables, segmentation, custom plugins
- **System**: Data management, health check, hot reload, SSO

Feature deployments may also have their own collections, to demonstrate the functionality they provide. If a feature deployment provides a collection, it will be located in the root of the feature deployment directory.

> **Note:** Some collections may contain examples that require specific licence grants.

## 7. Add Feature Deployments

To include optional features, such as OpenTelemetry, Kubernetes Operator, or GraphQL Federation, just append their deployment names to the `up.sh` command:

```bash
./up.sh otel-jaeger k8s-operator federation
```

Each feature deployment has its own readme located in the root of its deployment directory. It's recommend to review them for notes on usage.

## 8. Stopping and Restarting

To stop and remove all services and volumes:

```bash
./down.sh
```

To resume stopped services:

```bash
./up.sh
```

To restart individual services:

```bash
./docker-compose-command.sh restart tyk-dashboard
```

You can use `docker-compose-command.sh` as a wrapper to run Docker Compose commands in the correct context:

```bash
./docker-compose-command.sh ps
./docker-compose-command.sh logs -f tyk-gateway
```

## 9. Troubleshooting

### Check Logs for Errors

Check the logs:

```bash
./docker-compose-command.sh logs -f
```

### Check for Missing Hostnames

If `update-hosts.sh` fails, manually add entries from `deployments/tyk/data/misc/hosts/hosts.list` to your `/etc/hosts`.

### Check for Port Clashes

Some ports required by Tyk Demo may already be in use on your system. Either stop the services that are using the required ports, or change the ports used by Tyk Demo by modifying the relevent `docker-compose.yml` files.

Note that changing Tyk Demo ports may result in other issues, due to dependencies between components.

For more help, refer to the [troubleshooting guide](docs/TROUBLESHOOTING.md).

## 10. Environment Variables Reference

The Tyk Demo uses the `.env` file to configure various settings. Below is a list of commonly used environment variables, their descriptions, and defaults.

The only mandatory environment variable is `DASHBOARD_LICENCE`.

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `DASHBOARD_LICENCE` | Licence key for the Tyk Dashboard | Yes | None — **Must** be manually set |
| `INSTRUMENTATION_ENABLED` | Enables (`1`) or disables (`0`) instrumentation | No | `0` — Set automatically by `up.sh` |
| `TRACING_ENABLED` | Enables (`true`) or disables (`false`) tracing | No | `false` — Set automatically by `up.sh` |
| `GATEWAY_VERSION` | Tyk Gateway Docker image tag (e.g., `v5.8.0`) | No | Based on the latest release |
| `GATEWAY_LOGLEVEL` | Log level for the Tyk Gateway (e.g., `debug`, `info`) | No | `info` |
| `MDCB_LICENCE` | Licence key for the Tyk MDCB | Only when using the `mdcb` deployment | None — **Must** be manually set |
| `MDCB_USER_API_CREDENTIALS` | API credentials for MDCB to authenticate with the Dashboard | Only when using the `mdcb` deployment | None — Set automatically by `bootstrap.sh` |
| `PMP_SPLUNK_META_COLLECTORTOKEN` | Credentials for Tyk Pump to authenticate with the Splunk collector | Only when using the `analytics-splunk` deployment | None — Set automatically by `bootstrap.sh` |
| `NEW_RELIC_API_KEY` | API key for OpenTelemetry collector to send data to New Relic | Only when using the `otel/new-relic` deployment | None — **Must** be manually set |
| `NGROK_AUTHTOKEN` | Authentication token for the Ngrok agent | Only when using Ngrok or geolocation features | None — **Must** be manually set |
