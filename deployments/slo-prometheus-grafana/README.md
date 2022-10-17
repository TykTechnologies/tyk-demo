# SLIs and SLOs with Prometheus and Grafana for your APIs managed by Tyk
Ported over from Sonja's most excellent [OSS repo](https://github.com/TykTechnologies/demo-slo-prometheus-grafana)

## About

This demonstrates how to configure [Tyk Gateway](https://github.com/TykTechnologies/tyk), [Tyk Pump](https://github.com/TykTechnologies/tyk-pump), [Prometheus](https://prometheus.io/) and [Grafana OSS](https://grafana.com/grafana/) to set-up a dashboard with SLIs and SLOs for your APIs managed by Tyk.

You can use it to explore the Prometheus metrics exposed by Tyk Pump and use them in a Grafana dashboard.

![SLOs-for-APIs-managed-by-Tyk-Dashboards-Grafana](https://user-images.githubusercontent.com/17831497/187458994-a8bc0eae-e9b6-4af5-9233-034dc981bae6.png)

  
## Setup

1. Run the `up.sh` script with the `slo-prometheus-grafana` parameter:

```
./up.sh slo-prometheus-grafana
```


2. Generate traffic

[K6](https://k6.io/) is used to generate traffic to the API endpoints. The load script [load.js](./volumes/k6/load.js) will run for 15 minutes.

```
./docker-compose-command.sh run k6 run /scripts/load.js
```

You will see K6 output in your terminal:

<img width="963" alt="K6" src="https://user-images.githubusercontent.com/17831497/187454878-c1182107-7de2-4cd0-b572-9bcc80dde6c3.png">


3. Check out the dashboard in Grafana

Go to [Grafana](http://localhost:3020/) in your browser (initial user/pwd: admin/admin) and open the dashboard called [*SLOs for APIs managed by Tyk*](./volumes/grafana/dashboards/SLOs-for-APIs-managed-by-Tyk.json).

You should see the data coming in:
![tyk_grafana_initial](https://user-images.githubusercontent.com/17831497/187455646-077ac8a2-8279-4c23-8ca2-d276c0b2180b.png)

You can also filter the data per API:

<img width="472" alt="tyk_grafana_select_api" src="https://user-images.githubusercontent.com/17831497/187456007-e989119e-053a-4ff7-bc3a-5afd92482d5b.png">


## How this works

![slo_grafana](https://github.com/TykTechnologies/demo-slo-prometheus-grafana/blob/main/doc/slo_grafana.png)

### Configuration

* Tyk API Gateway is configured to expose two API endpoint:
  *  httpbin ([see .json config](./data/apis/httpbin.json))
  *  httpstatus ([see .json config](./data/apis/httpstatus.json))
* K6 will use the load script [load.js](./volumes/k6/load.js) to generate demo traffic to the API endpoints
* Tyk Pump is configured to expose a metric endpoint for Prometheus ([see config](./volumes/tyk-pump/pump.conf)) with two custom metrics called `tyk_http_requests_total` and `tyk_http_latency`. Tyk Pump version >= 1.6. is needed for custom metrics.
* Prometheus
  * [prometheus.yml](./volumes/prometheus/prometheus.yml) is configured to automatically scrape Tyk Pump's metric endpoint
  * [slos.rules.yml](./volumes/prometheus/slos.rules.yml) is used to calculate additional metrics needed for the remaining error budget
* Grafana
  * [prometheus_ds.yml](./volumes/grafana/datasources/prometheus_ds.yml) is configured to connect Grafana automatically to Prometheus
  * [SLOs-for-APIs-managed-by-Tyk.json](./volumes/grafana/dashboards/SLOs-for-APIs-managed-by-Tyk.json) is the dashboard definition


### SLIs and SLOs

Definition and example inspired from https://sre.google/workbook/slo-document/, https://landing.google.com/sre/workbook/chapters/alerting-on-slos/ and https://github.com/google/prometheus-slo-burn-example/blob/master/prometheus/slos.rules.yml.

You will see different indicators displayed on the Grafana dashboard. 

To calculate the SLO and the displayed error budget remaining, we use the following SLI/SLO:
* SLI: the proportion of successful HTTP requests, as measured from Tyk API Gateway
  *  Any HTTP status other than 500–599 is considered successful.
  *  count of http_requests which do not have a 5XX status code divided by count of all http_requests
*  SLO: 95% successful requests

In [slos.rules.yml](./volumes/prometheus/slos.rules.yml) we calculate the rate of error per requests for the last 10 minute in `job:slo_errors_per_request:ratio_rate10m`. With `job:error_budget:remaining` we calculate the error budget remaining in percent. This is what we display in the Grafana dashboard. We use a threshold of 95% in the dashboard (every value below 95% is red).