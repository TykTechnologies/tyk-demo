# New Relic

New Relic offers observability and tracing capabilities via OpenTelemetry. You can view detailed metrics, logs, and traces through New Relic's Dashboard.

Since New Relic is a cloud-based service, it retains data based on your subscription level, even if your application or container restarts.

- [New Relic Dashboard](https://one.newrelic.com/)

## Setup

Before running the setup script, make sure to set your `NEW_RELIC_API_KEY` in the `.env` file. More info on how to get your API Key can be found [here](https://docs.newrelic.com/docs/apis/intro-apis/new-relic-api-keys/).

You can run the setup using a script similar to the one used for Jaeger:

```bash
./up.sh otel/new-relic
```

## Usage

To use New Relic, open the [New Relic Dashboard](https://one.newrelic.com/) in a browser. The _APM & Services_ page displays a list of services, including `tyk-gateway`. Click on a service to view detailed metrics, logs, and traces.
For more information, check out the [Tyk + New Relic documentation](https://tyk.io/docs/product-stack/tyk-gateway/advanced-configurations/distributed-tracing/open-telemetry/otel_new_relic/)
