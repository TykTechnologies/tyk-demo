#!/bin/bash

source scripts/common.sh
deployment="Splunk Analytics"
log_start_deployment
bootstrap_progress

splunk_base_url="http://localhost:8000"
splunk_base_mgmt_url="https://localhost:8089"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)

log_message "Waiting for splunk to return desired response"
wait_for_response "$splunk_base_url/en-GB/account/login" "200"

log_message "Adding http event collector"
log_http_result "$(curl -k $splunk_base_mgmt_url/servicesNS/admin/splunk_httpinput/data/inputs/http -s -o .context-data/splunk-http-collector -w "%{http_code}" \
  -u admin:mypassword \
  -d name=tyk \
  -d output_mode=json 2>> logs/bootstrap.log)"
bootstrap_progress

log_message "Setting Splunk HTTP Event Collector Token"
splunk_token=$(cat .context-data/splunk-http-collector | jq -r '.entry[0] .content .token')
set_docker_environment_value "PMP_SPLUNK_META_COLLECTORTOKEN" "$splunk_token"
log_ok
bootstrap_progress

log_message "Recreating tyk-splunk-pump to utilise collector token"
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate tyk-splunk-pump 1>/dev/null 2>>logs/bootstrap.log
log_ok
bootstrap_progress

log_message "Stopping the tyk-pump service (from Tyk deployment), to prevent it consuming analytics data intended for this deployment's Pump"
eval $(generate_docker_compose_command) stop tyk-pump 2> /dev/null
if [ "$?" != 0 ]; then
  echo "Error stopping Pump service tyk-pump"
  exit 1
fi
log_ok
bootstrap_progress

# verify tyk-pump service is stopped
log_message "Checking that of tyk-pump service is stopped"
service_process=$(eval $(generate_docker_compose_command) top tyk-pump)
if [ "$service_process" != "" ]; then
  log_message "  ERROR: tyk-pump process has not stopped. Exiting."
  exit 1
fi
log_ok
bootstrap_progress

log_message "Waiting for API availability"
# this api id is for the 'basic open api' called by the next section
wait_for_api_loaded "basic-open-api" "$gateway_base_url" "$gateway_api_credentials"
# this api id is for the 'httpbin acme' API called by the deployment tests
wait_for_api_loaded "93fd5c15961041115974216e7a3e7175" "$gateway_base_url" "$gateway_api_credentials"
log_ok
bootstrap_progress        

log_message "Sending a test request to provide Splunk with data"
# since request sent in base bootstrap process will not have been picked up by elasticsearch-enabled pump
log_http_result "$(curl -s localhost:8080/basic-open-api/get -o /dev/null -w "%{http_code}" 2>> logs/bootstrap.log)"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Analytics
  ▽ Splunk
                    URL : $splunk_base_url
               Username : admin
               Password : mypassword
        Collector Token : $splunk_token"
