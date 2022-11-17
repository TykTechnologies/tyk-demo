# Analytics Export

Demonstrates how analytics data can be pushed into 3rd party databases and reported on by 3rd party systems. This is achieved by using Tyk Pump to push analytics data to ElasticSearch and reporting on it in Kibana.

- [Kibana Dashboard](http://localhost:5601)

## Setup

Run the `up.sh` script with the `analytics` parameter:

```
./up.sh analytics-kibana
```

### Postman Collection

You can import the deployment-specific Postman collection `tyk_demo_analytics_kibana.postman_collection.json`.

## Analytics data processing

The Tyk Pump deployed with Kibana is already configured to push data to the Elasticsearch container, so Kibana can visualise this data.

The bootstrap process creates an Index Pattern and Visualization which can be used to view API analytics data. It will also stop the original Pump deployed by `deployments/tyk/docker-compose.yml`, so that the Elasticsearch-enabled Pump deployed by `docker-compose.yml` can take over.

### Analytics sharding

[Analytics sharding](https://tyk.io/docs/tyk-pump/configuration/#sharding-analytics-to-different-data-sinks) enables the Pump to filter analytics data so it only processes data for specific APIs or Organisations.

In this deployment, the Pump configuration for Elasticsearch contains a `filters` section that has the id for the Acme Organisation in the *skip* list. This means that the Pump will not send any analytics data for Acme-related APIs to Elasticsearch. The filters can be set up to specify Organisations and APIs to either include or exclude.

See the **Analytics Sharding** request in the `tyk_demo_analytics_kibana.postman_collection` Postman collection for a working example.

### Troubleshooting (Resources)
Please note that you may have to increase the allocation of default docker resources in order for this deployment to work properly. The default configuration of 2CPUs and 2GB of Memory had some non-apparent issues with the elasticsearch container crashing.  Docker Engine on OSX provisioned with 8 CPUs and 8GB of memory was able to spin this deployment up with no issues.
