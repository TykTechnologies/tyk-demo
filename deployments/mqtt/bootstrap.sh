#!/bin/bash

source scripts/common.sh
deployment="MQTT"

log_start_deployment
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
gateway_base_url="http://tyk-gateway.localhost:8080"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)

log_message "Importing MQTT APIs"
log_json_result "$(curl $dashboard_base_url/admin/apis/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat deployments/mqtt/data/tyk-dashboard/apis.json)")"
bootstrap_progress

log_message "Hot reloading Gateways"
hot_reload "$gateway_base_url" "$gateway_api_credentials" "group"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ MQTT
  ▽ Node-Red
                    URL : http://localhost:1880
  ▽ Mosquitto (Broker)
                    URL : http://localhost:1883"
