#!/bin/bash

source scripts/common.sh
deployment="Analytics - Kibana"
log_start_deployment
bootstrap_progress

kibana_base_url="http://localhost:5601"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)

log_message "Waiting for kibana to return desired response"
wait_for_response "$kibana_base_url/app/kibana" "200"

log_message "Pausing briefly before attempting to apply Kibana configuration, to avoid receiving HTTP 429 (too many requests)"
sleep 2

log_message "Adding index pattern to Kibana"
log_http_result "$(curl $kibana_base_url/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2?overwrite=true -s -o /dev/null -w "%{http_code}" \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @deployments/analytics-kibana/data/kibana/index-patterns/tyk-analytics.json 2>> logs/bootstrap.log)"
bootstrap_progress

log_message "Adding visualisation to Kibana"
log_http_result "$(curl $kibana_base_url/api/saved_objects/visualization/407e91c0-8168-11ea-9323-293461ad91e5?overwrite=true -s -o /dev/null -w "%{http_code}" \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @deployments/analytics-kibana/data/kibana/visualizations/request-count-by-time.json 2>> logs/bootstrap.log)"
bootstrap_progress

log_message "Stopping the tyk-pump service (from Tyk deployment), preventing it from consuming the analytics records which we want to be processed by the Pump from this deployment."
eval $(generate_docker_compose_command) stop tyk-pump 2> /dev/null
if [ "$?" != 0 ]; then
  echo "Error stopping tyk-pump service"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Verifying that tyk-pump service has stopped"
service_process=$(eval $(generate_docker_compose_command) top tyk-pump)
if [ "$service_process" != "" ]; then
  log_message "  ERROR: tyk-pump process has not stopped. Exiting."
  exit 1
fi
log_ok
bootstrap_progress

log_message "Wait for API availability"
# this api id is for the 'basic open api' called by the next section
wait_for_api_loaded "727dad853a8a45f64ab981154d1ffdad" "$gateway_base_url" "$gateway_api_credentials"
log_ok
bootstrap_progress        

log_message "Sending a test request to provide Kibana with data, as Tyk bootstrap requests will not have been picked up by the Pump from this deployment"
log_http_result "$(curl -s localhost:8080/basic-open-api/get -o /dev/null -w "%{http_code}" 2>> logs/bootstrap.log)"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Analytics - Kibana
  ▽ Kibana
                    URL : $kibana_base_url"
