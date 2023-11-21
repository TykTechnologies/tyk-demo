# Jaeger

Jaeger can demonstrate tracing via Open Telemetry. It has a [Dashboard](http://localhost:16686/) you can use to view traces.

It has been configured to use in-memory storage, so will not retain data once the container is restarted/removed.

- [Jaeger Dashboard](http://localhost:16686/)

## Setup

Run the `up.sh` script with the `otel-jaeger` parameter:

```
./up.sh otel-jaeger
```

## Usage

To use Jaeger, open the [Jaeger Dashboard](http://localhost:16686/) in a browser. The _Search_ page displays trace data based on filters:

- For _Service_, select `tyk-gateway` to see traces from the Tyk gateway, or select `jaeger-query` to see traces from the Jaeger application.
- The values for _Operation_ change based on the _service_. Leave it on `all` to see everything.
- _Lookback_ filters by time, by limiting displayed data to the selected time period.

Tyk Demo generates trace data as a byproduct of the bootstrap process, so you should see trace entries for the `tyk-gateway` service without having to send any API requests yourself. However, if you don't see any data, try increasing the duration of the _Lookback_ filter to a longer period, or generate some fresh trace data by [sending a basic request](http://tyk-gateway.localhost:8080/basic-open-api/get) to the Gateway.
