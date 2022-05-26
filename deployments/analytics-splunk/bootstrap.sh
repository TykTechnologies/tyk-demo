#!/bin/bash

source scripts/common.sh
deployment="Splunk Analytics"
log_start_deployment
bootstrap_progress

splunk_base_url="http://localhost:8000"
splunk_base_mgmt_url="https://localhost:8089"
pump_container_name="$(get_context_data "container" "pump" "1" "name")"

log_message "Waiting for splunk to return desired response"
wait_for_response "$splunk_base_url/en-GB/account/login" "200"

log_message "Adding http event collector"
log_http_result "$(curl -k $splunk_base_mgmt_url/servicesNS/admin/splunk_httpinput/data/inputs/http -s -o .context-data/splunk-http-collector -w "%{http_code}" \
  -u admin:mypassword \
  -d name=tyk \
  -d output_mode=json 2>> bootstrap.log)"
bootstrap_progress

# set Splunk token and restart the Splunk Pump container
log_message "Setting Splunk HTTP Event Collector Token"
splunk_token=$(cat .context-data/splunk-http-collector | jq -r '.entry[0] .content .token')
set_docker_environment_value "PMP_SPLUNK_META_COLLECTORTOKEN" "$splunk_token"
log_ok
bootstrap_progress


# Configure splunk token in splunk-pump.conf
log_message "Adding updated splunk token in splunk-pump.conf"
jq --arg a "$splunk_token" '.pumps.splunk.meta.collector_token = $a' ./deployments/analytics-splunk/volumes/tyk-pump/splunk-pump.conf > ./deployments/analytics-splunk/volumes/tyk-pump/splunk-pump.conf.tmp && mv ./deployments/analytics-splunk/volumes/tyk-pump/splunk-pump.conf.tmp ./deployments/analytics-splunk/volumes/tyk-pump/splunk-pump.conf
log_message "Restarting tyk-splunk-pump"
$(generate_docker_compose_command) restart tyk-splunk-pump 2>/dev/null
log_ok
bootstrap_progress


log_message "Stopping the tyk-pump service (from Tyk deployment), to prevent it consuming analytics data intended for this deployment's Pump"
eval $(generate_docker_compose_command) stop tyk-pump 2> /dev/null
if [ "$?" != 0 ]; then
  echo "Error stopping Pump contsainer $pump_container_name"
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

log_message "Sending a test request to provide Splunk with data"
# since request sent in base bootstrap process will not have been picked up by elasticsearch-enabled pump
log_http_result "$(curl -s localhost:8080/basic-open-api/get -o /dev/null -w "%{http_code}" 2>> bootstrap.log)"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Analytics
  ▽ Splunk
                    URL : $splunk_base_url
               Username : admin
               Password : mypassword
        Collector Token : $splunk_token"
