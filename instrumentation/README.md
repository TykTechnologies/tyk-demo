## Graphite

Graphite demonstrates the [instrumentation feature](https://tyk.io/docs/basic-config-and-security/report-monitor-trigger-events/instrumentation/) of Tyk whereby realtime statistics are pushed from the Dashboard, Gateway and Pump into a StatsD instance. For this example, the statistics can be seen in the [Graphite Dashboard](http://localhost:8060)

* [Graphite Dashboard](http://localhost:8060)

### Setup

Setting the environment variable for this feature is handled by the `bootstrap.sh` script.

The Docker environment variable `TRACING_ENABLED` is automatically set to `TRUE` by the `bootstrap.sh` script.

The StatsD, Carbon and Graphite are all deployed within a single container service called `graphite`.

### Usage

Open the [Graphite Dashboard](http://localhost:8060]). Explore the 'Metrics' tree, and click on items you are interested in seeing, this will add them to the graph. Most of the Tyk items are in `stats` and `stats_counts`.  Try sending some requests through the Gateway to generate data.
