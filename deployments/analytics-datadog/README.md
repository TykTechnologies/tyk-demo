# Analytics Export

Demonstrates how analytics data can be pushed into 3rd party databases and reported on by 3rd party systems. 
This is achieved by using Tyk Pump to push analytics data to Datadog agent and reporting on it in 
[Datadog portal](https://app.datadoghq.com/infrastructure/map).

## Analytics data processing

The bootstrap process stop the original Pump deployed by `deployments/tyk/docker-compose.yml`, so that the Datadog-enabled Pump deployed by `docker-compose.yml` can take over.
(If you have 2 different pumps one will compete with the other, and you won't see the records where you expect them)
In pump.conf (`deployments/analytics-datadog/volumes/tyk-pump/pump-datadog.conf`) you will find two pumps:
1. Datadog-pump - is pushing request time data to the DogStatsD (Datadog) agent via UDP
2. stdout-pump Datadog-pump - is pushing the pump process logs including the all the raw requests to the Datadog agent.

Datadog agent is running in docker (/deployments/analytics-datadog/docker-compose.yaml) and configured to run also as 
DogstatsD i.e. StatsD daemon that listens for statistics sent over UDP and forward them to the Datadog site, so you can
create graphs and analyse your data in the Datadog portal.
The DogstatsD is enabled in `/deployments/analytics-datadog/data/datadog.yaml`, on port `8126`. This port is also exposed 
outside the tyk docker network.

The metrics Tyk sends to Datadog can be found under the `tyk` namespace.

## Setup

1. Get a Datadog user. 
   In the future we'll provide a dashboard via Datadog integration or marketplace.

2. Set up the following Datadog environment variables:

| DD Environment variable   |  Value           | Description |
|---------------------------|:-------------:|------:|
| DD_API_KEY | {your-datadog-api-key} | For the DD agent to connect the DD portal |
| DD_ENV |    tyk-demo-env   |   To set environment name |
| DD_SITE |    {your-datadog-site-url}   |   By default this should be `datadoghq.com` but if registered in EU use `datadoghq.eu` |
| DD_DOGSTATSD_TAGS | "env:tyk-demo" |  Additional tags to append to all metrics, events, and service checks received by this DogStatsD server |
| DD_LOGS_ENABLED | true | For the DD agent to enable logs collection |
| DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL | true | To skip the DD logs |
| DD_DOGSTATSD_SOCKET | /var/run/docker.sock | Path to the Unix socket to listen to.  Docker compose mounts this path |
| DD_DOGSTATSD_ORIGIN_DETECTION | true | Enable container detection and tagging for unix socket metrics |
| DD_DOGSTATSD_NON_LOCAL_TRAFFIC | true | Listen to DogStatsD packets from other containers (required to send custom metrics) |
| DD_AGENT_HOST | dd-agent | Name of the agent host in docker |
| DD_AC_EXCLUDE | redis | To exclude DD redis checks |
| DD_CONTAINER_EXCLUDE | true | To exclude docker checks for the DD agent|

```
   DD_API_KEY={your-datadog-api-key}
   DD_SITE={your-datadog-site-url}
   DD_DOGSTATSD_TAGS="env:tyk-demo"
   DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true
   DD_LOGS_ENABLED=true
   DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
   DD_DOGSTATSD_SOCKET=/var/run/docker.sock
   DD_AGENT_HOST=dd-agent
   DD_AC_EXCLUDE=redis
   DD_CONTAINER_EXCLUDE=dd-agent
   DD_PROCESS_AGENT_ENABLED=true
   DD_LOG_LEVEL=debug
   DD_DOGSTATSD_ORIGIN_DETECTION=true
```

3. Run the `up.sh` script with the `analytics-datadog` parameter:

```
./up.sh analytics-datadog
```

## Postman Collection

To test and see some data in Datadog portal, just run a few api calls via Tyk and then you create graphs in datadog based on 
that traffic:

1. Install hey, a tiny program to do some load to a web application.
`brew install hey`

2. Run load test to a service behind Tyk
`hey -n 2000 http://tyk-gateway.localhost:8080/basic-open-api/ip`


If you run it with bench suite you can use the bench upstream to test Tyk response time:

1. Start Tyk demo with bench suit and datadog
`./up.sh analytics-datadog bench`

2. Test the upstream bench suite
```
hey -n 2000 http://bench:8889/json/valid -H "X-Delay: 2s"
```

3. Test the response time with Tyk in the middle, using the api `/bench-uptream`:
```
hey -n 2000 http://tyk-gateway.localhost:8080/bench-uptream/json/valid -H "X-Delay: 2s" -m GET
```

4. Compare
