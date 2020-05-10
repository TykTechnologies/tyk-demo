## Zipkin

Zipkin can demonstrate open tracing. It has a [Dashboard](http://localhost:9411) you can use to view traces.

It has been configured to use in-memory storage, so will not retain data once the contain is restarted/removed.

- [Zipkin Dashboard](http://localhost:9411)

### Setup

Set the `INSTRUMENTATION_ENABLED` variable to `1` in the Docker environment variable `.env`.

This is automatically handled by the `bootstrap.sh` script.

### Usage 

To use Zipkin, open the [Zipkin Dashboard](http://localhost:9411) in a browser and click the magnifying glass icon, this will conduct a search for all available traces. You can add filters for the trace search. There should be at least one trace entry for the "Basic Open API", which is made during the bootstrap process. If you don't see any data, try changing the duration filter to longer period.