## Kibana

Demonstrates how analytics data can be push into 3rd party databases and reported on by 3rd party systems.

- [Kibana Dashboard](http://localhost:5601)

### Analytics data processing

The Tyk Pump deployed with Kibana is already configured to push data to the Elasticsearch container, so Kibana can visualise this data.

The bootstrap process creates an Index Pattern and Visualization which can be used to view API analytics data. It will also stop the original Tyk Pump which is deployed, so that the Elasticsearch-enabled pump can take over.