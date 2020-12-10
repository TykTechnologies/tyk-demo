# Splunk Analytics Export

Demonstrates how analytics data can be pushed into 3rd party databases and reported on by 3rd party systems. This is achieved by using Tyk Pump to push analytics data to Splunk.

- [Splunk Dashboard](http://localhost:8000)

## Setup

Run the `up.sh` script with the `analytics-splunk` parameter:

```
./up.sh analytics-splunk
```

### Postman Collection

You can import the deployment-specific Postman collection `tyk_demo_analytics_splunk.postman_collection.json`.

## Analytics data processing

The Tyk Pump deployed with Splunk is already configured to push data to the Splunk container, ready to be visualised.

The bootstrap process creates a HTTP Event Collector which can be used to view API analytics data. It will also stop the original Pump deployed by `deployments/tyk/docker-compose.yml`, so that the Splunk-enabled Pump deployed by `docker-compose.yml` can take over.

**Note:** The HTTP Event Collector created by the bootstrap returns a collector token, which needs to be injected into `splunk-pump.conf`.  Ideally the bootstrap process should configure this automatically via an environment variable, but unfortunately there are no Tyk Pump Splunk environment variables right now.  Consequently, the value for `meta.collector_token` in `splunk-pump.conf` needs to be manually updated with the splunk collector token.


### Analytics sharding

[Analytics sharding](https://tyk.io/docs/tyk-configuration-reference/tyk-pump-configuration/tyk-pump-configuration/#sharding-analytics-to-different-data-sinks) enables the Pump to filter analytics data so it only processes data for specific APIs or Organisations.

In this deployment, the Pump configuration for Splunk contains a `filters` section that has the id for the Acme Organisation in the *skip* list. This means that the Pump will not send any analytics data for Acme-related APIs to Splunk. The filters can be set up to specify Organisations and APIs to either include or exclude.

See the **Analytics Sharding** request in the `tyk_demo_analytics_splunk.postman_collection` Postman collection for a working example.
