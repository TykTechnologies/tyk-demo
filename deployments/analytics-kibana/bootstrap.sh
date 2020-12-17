#!/bin/bash

source scripts/common.sh
deployment="Analytics - Kibana"
log_start_deployment
bootstrap_progress

kibana_base_url="http://localhost:5601"

log_message "Waiting for kibana to return desired response"
wait_for_response "$kibana_base_url/app/kibana" "200"

log_message "Adding index pattern"
log_http_result "$(curl $kibana_base_url/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2?overwrite=true -s -o /dev/null -w "%{http_code}" \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @deployments/analytics-kibana/data/kibana/index-patterns/tyk-analytics.json 2>> bootstrap.log)"
bootstrap_progress

log_message "Adding visualisation"
log_http_result "$(curl $kibana_base_url/api/saved_objects/visualization/407e91c0-8168-11ea-9323-293461ad91e5?overwrite=true -s -o /dev/null -w "%{http_code}" \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @deployments/analytics-kibana/data/kibana/visualizations/request-count-by-time.json 2>> bootstrap.log)"
bootstrap_progress

log_message "Stopping the pump instance deployed by the base deployment"
# so it is replaced by the instance from this deployment
docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) stop tyk-pump 2> /dev/null
log_ok
bootstrap_progress

log_message "Sending a test request to provide Kibana with data"
# since request sent in base bootstrap process will not have been picked up by elasticsearch-enabled pump
log_http_result "$(curl -s localhost:8080/basic-open-api/get -o /dev/null -w "%{http_code}" 2>> bootstrap.log)"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Analytics - Kibana
  ▽ Kibana
                    URL : $kibana_base_url"