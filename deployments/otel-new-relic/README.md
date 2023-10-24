# New Relic

New Relic offers observability and tracing capabilities via OpenTelemetry. You can view detailed metrics, logs, and traces through New Relic's Dashboard.

Since New Relic is a cloud-based service, it retains data based on your subscription level, even if your application or container restarts.

- [New Relic Dashboard](https://one.newrelic.com/)

## Setup

Note: A New Relic account is required to use this deployment. If you don't have an account, you will need to create one before continuing with the setup - sign up for free via the New Relic website.

Before running the setup script, make sure to set the necessary environment variables in the `.env` file.  

| Variable | Description | Required | Default |
| -------- | ----------- | -------- | ------- |
| NEW_RELIC_LICENSE_KEY | Sets the licence key sent to New Relic by the Otel collector | Yes | No default. You must use your own API key, which you can find in your New Relic dashboard. Note that New Relic provides several API keys - you need to use a key of the type *INGESS - LICENCE*. More info on how to get your API Key can be found [here](https://docs.newrelic.com/docs/apis/intro-apis/new-relic-api-keys/). |
| NEW_RELIC_OTEL_EXPORTER_OTLP_ENDPOINT | Sets the endpoint to which the Otel collector will send data | Maybe! | Defaults to `otlp.nr-data.net`. However, if you have registered with New Relic's EU dashboard (i.e. your dashboard domain is `one.eu.newrelic.com`) then you must override the default by setting this variable to `otlp.eu01.nr-data.net`. |

Setup the deployment by running the `up.sh` script with the `otel-new-relic` parameter:

```bash
./up.sh otel-new-relic
```

## Usage

To see the Tyk trace data in New Relic, open the [New Relic Dashboard](https://one.newrelic.com/) in a browser. The _APM & Services_ page displays a list of services, including `tyk-gateway`. Click on a service to view detailed metrics, logs, and traces.
For more information, check out the [Tyk + New Relic documentation](https://tyk.io/docs/product-stack/tyk-gateway/advanced-configurations/distributed-tracing/open-telemetry/otel_new_relic/)

The Tyk Demo bootstrapping process generates request data, so you should find Tyk data in your New Relic dashboard shortly after the `up.sh` bootstrap script has completed.

## Troubleshooting

#### No data is appearing in New Relic

This could be caused by data being sent to the wrong export endpoint.

To check this, first review the OTel collector container log:

```bash
docker logs -f tyk-demo-collector-gateway-1
```

Check if the log contains an error similar to this:

```log
2023-10-24T14:48:32.995Z	error	exporterhelper/queued_retry.go:391	Exporting failed. The error is not retryable. Dropping data.	{"kind": "exporter", "data_type": "traces", "name": "otlp", "error": "Permanent error: rpc error: code = PermissionDenied desc = unexpected HTTP status code received from server: 403 (Forbidden)", "dropped_items": 161}
```

If a similar error is present then it's likely that you need to set the `NEW_RELIC_OTEL_EXPORTER_OTLP_ENDPOINT` environment variable to use the EU endpoint `otlp.eu01.nr-data.net`. To do this, add the follow line to the `.env` file, then recreate the Tyk Demo deployment:

```
NEW_RELIC_OTEL_EXPORTER_OTLP_ENDPOINT=otlp.eu01.nr-data.net
```
