# Jaeger

Jaeger can demonstrate tracing via Open Telemetry. It has a [Dashboard](http://localhost:16686/) you can use to view traces.

It has been configured to use in-memory storage, so will not retain data once the contain is restarted/removed.

- [Jaeger Dashboard](http://localhost:16686/)

## Setup

Run the `up.sh` script with the `otel` parameter:

```
./up.sh otel
```

## Usage 

To use Jaeger, open the [Jaeger Dashboard](http://localhost:16686/) in a browser and click the magnifying glass icon, this will conduct a search for all available traces. You can add filters for the trace search. There should be at least one trace entry for the "Basic Open API", which is made during the bootstrap process. If you don't see any data, try changing the duration filter to longer period.
