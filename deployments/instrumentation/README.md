# Instrumentation

Graphite demonstrates the [instrumentation feature](https://tyk.io/docs/basic-config-and-security/report-monitor-trigger-events/instrumentation/) of Tyk whereby realtime statistics are pushed from the Dashboard, Gateway and Pump into a StatsD instance. For this example, the statistics can be seen in the [Graphite Dashboard](http://localhost:8060)

* [Graphite Dashboard](http://localhost:8060)

## Setup

Run the `up.sh` script with the `instrumentation` parameter:

```
./up.sh instrumentation
```

The StatsD, Carbon and Graphite applications are all deployed within a single container service called `graphite`.

### Environment variable

The Docker environment variable `TRACING_ENABLED` is required to be set to `TRUE` in the `.env` file. The bootstrap process will set this automatically when running the `up.sh` script.

## Usage

Open the [Graphite Dashboard](http://localhost:8060]). Explore the 'Metrics' tree, and click on items you are interested in seeing, this will add them to the graph. Most of the Tyk items are in `stats` and `stats_counts`.  Try sending some requests through the Gateway to generate data.

You may need to send some test API requests to generate instrumentation data. Also, try clicking the refresh icon to reload the available metrics.
