# Jaeger

Jaeger can demonstrate tracing via Open Telemetry. It has a [Dashboard](http://localhost:16686/) you can use to view traces.

It has been configured to use in-memory storage, so will not retain data once the container is restarted/removed.

- [Jaeger Dashboard](http://localhost:16686/)

## Setup

Run the `up.sh` script with the `otel` parameter:

```
./up.sh otel
```

## Usage 

To use Jaeger, open the [Jaeger Dashboard](http://localhost:16686/) in a browser. The *Search* page displays trace data based on filters:

- For *Service*, select `tyk-gateway` to see traces from the Tyk gateway, or select `jaeger-query` to see traces from the Jaeger application.
- The values for *Operation* change based on the *service*. Leave it on `all` to see everything.
- *Lookback* filters by time, by limiting displayed data to the selected time period. 

Tyk Demo generates trace data as a byproduct of the bootstrap process, so you should see trace entries for the `tyk-gateway` service without having to send any API requests yourself. However, if you don't see any data, try increasing the duration of the *Lookback* filter to a longer period, or generate some fresh trace data by [sending a basic request](http://tyk-gateway.localhost:8080/basic-open-api/get) to the Gateway.
