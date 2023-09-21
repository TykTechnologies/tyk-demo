# New Relic

New Relic offers observability and tracing capabilities via OpenTelemetry. You can view detailed metrics, logs, and traces through New Relic's Dashboard.

Since New Relic is a cloud-based service, it retains data based on your subscription level, even if your application or container restarts.

- [New Relic Dashboard](https://one.newrelic.com/)

## Setup

To set up New Relic with OpenTelemetry, you generally need to install the OpenTelemetry SDK in your application and configure it to send data to New Relic's endpoint. You'll also need your New Relic API key for authentication.

Before running the setup script, make sure to set your New Relic API key in the `volumes/otel-collector.yml` file. Locate the following section in the YAML file and replace `your_api_key_here` with your actual New Relic API key:

You can run the setup using a script similar to the one used for Jaeger:

```bash
./up.sh otel/new-relic
```

**Note**: The actual setup process may vary depending on your application and technology stack, so refer to the New Relic documentation for specific guidelines.
