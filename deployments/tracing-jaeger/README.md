# Zipkin

Jaeger can demonstrate open tracing. It has a [Jaeger Dashboard](http://localhost:16686/search) you can use to view traces.

It has been configured to use in-memory storage, so will not retain data once the container is restarted/removed.

- [Jaeger Dashboard](http://localhost:16686/search)

## Setup

Run the `up.sh` script with the `tracing-jaeger` parameter:

```
./up.sh tracing-jaeger
```
or with `make`:
```
make boot deploy="tracing-jaeger"
```

### Environment variable

The Docker environment variable `TRACING_ENABLED` is required to be set to `true` in the `.env` file. The bootstrap process will set this automatically when running the `up.sh` script.

## Usage 

To use Jaeger, open the [Jaeger Dashboard](http://localhost:16686/search) in a browser and click the magnifying glass icon, this will conduct a search for all available traces. You can add filters for the trace search. There should be at least one trace entry for the "Basic Open API", which is made during the bootstrap process. If you don't see any data, try changing the duration filter to longer period.
