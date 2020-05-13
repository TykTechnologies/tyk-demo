# Analytics Export

Demonstrates how analytics data can be pushed into 3rd party databases and reported on by 3rd party systems. This is achieved by using Tyk Pump to push analytics data to ElasticSearch and reporting on it in Kibana.

- [Kibana Dashboard](http://localhost:5601)

## Setup

Run the `up.sh` script with the `analytics` parameter:

```
./up.sh analytics
```

## Analytics data processing

The Tyk Pump deployed with Kibana is already configured to push data to the Elasticsearch container, so Kibana can visualise this data.

The bootstrap process creates an Index Pattern and Visualization which can be used to view API analytics data. It will also stop the original Pump deployed by `deployments/tyk/docker-compose.yml`, so that the Elasticsearch-enabled Pump deployed by `docker-compose.yml` can take over.