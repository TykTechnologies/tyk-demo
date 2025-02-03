#!/bin/bash

source scripts/common.sh
deployment="MDCB"

log_start_deployment
bootstrap_progress

log_message "Setting global variables"
worker_gateway_base_url="http://tyk-worker-gateway.localhost:8090"
dashboard_base_url="http://tyk-dashboard.localhost:3000"
log_ok
bootstrap_progress

# check MDCB licence exists
log_message "Checking MDCB licence exists"
if ! grep -q "MDCB_LICENCE=" .env; then
  echo "ERROR: MDCB licence missing from Docker environment file. Add a licence to the MDCB_LICENCE variable in the .env file."
  exit 1
fi
log_ok
bootstrap_progress

# check the MDCB licence expiry
log_message "Checking MDCB licence expiry"
licence_days_remaining=0
check_licence_expiry "MDCB_LICENCE"
if [[ "$?" -eq "1" ]]; then
  echo "ERROR: Tyk MDCB licence has expired. Update MDCB_LICENCE variable in .env file with a new licence."
  exit 1
fi
mdcb_licence_days_remaining=$licence_days_remaining
bootstrap_progress

# set up MDCB user in Dashboard
log_message "Creating Dashboard MDCB user, to obtain Dashboard API credentials"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>> logs/bootstrap.log)
dashboard_mdcb_user_email=$(jq -r '.email_address' deployments/mdcb/data/tyk-dashboard/dashboard-mdcb-user.json)
dashboard_mdcb_user_password=$(jq -r '.password' deployments/mdcb/data/tyk-dashboard/dashboard-mdcb-user.json)
dashboard_mdcb_user_api_response=$(curl $dashboard_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @deployments/mdcb/data/tyk-dashboard/dashboard-mdcb-user.json 2>> logs/bootstrap.log \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard_mdcb_user_id=$(echo $dashboard_mdcb_user_api_response | jq -r '.id')
dashboard_mdcb_user_api_credentials=$(echo $dashboard_mdcb_user_api_response | jq -r '.api_key')
log_ok
bootstrap_progress

# set MDCB credentials and recreate the MDCB container
log_message "Setting Docker environment variable for MDCB user API credentials"
set_docker_environment_value "MDCB_USER_API_CREDENTIALS" "$dashboard_mdcb_user_api_credentials"
log_ok
bootstrap_progress

log_message "Setting Docker environment variable for Ngrok tunnel MDCB URL"
ngrok_mdcb_tunnel_url=$(get_context_data "1" "ngrok" "1" "mdcb-url")
if [ "$ngrok_mdcb_tunnel_url" == "" ]; then
  log_message "  Ngrok tunnel URL for MDCB not found. Skipping."
  ngrok_mdcb_tunnel_url="N/A"
else
  ngrok_mdcb_tunnel_url=$(echo "$ngrok_mdcb_tunnel_url" | cut -d'/' -f3)
  log_message "  Using: $ngrok_mdcb_tunnel_url"
  set_docker_environment_value "NGROK_MDCB_TUNNEL_URL" "$ngrok_mdcb_tunnel_url"
fi

# recreate containers to use updated environment variables
log_message "Recreating MDCB deployment containers, so that they use updated MDCB user API credentials (tyk-mdcb, tyk-worker-gateway tyk-worker-gateway-ngrok)"
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate tyk-mdcb tyk-worker-gateway tyk-worker-gateway-ngrok 2> /dev/null
if [ "$?" != "0" ]; then
  echo "Error occurred when recreating MDCB deployment containers"
  exit 1
fi
log_ok
bootstrap_progress

# verify MDCB container is running
log_message "Verifying that MDCB service container is running (tyk-mdcb)"
mdcb_running=$(get_service_container_data tyk-mdcb "{{ .State.Running }}")
if [ "$mdcb_running" != "true" ]; then
  log_message "  ERROR: No running container for tyk-mdcb service. Exiting."
  log_message "  Suggest checking MDCB container log for more information. Perhaps the MDCB licence has expired?"
  exit 1
fi
log_ok
bootstrap_progress

# check status of worker gateway
log_message "Checking that worker Gateway is accessible (tyk-worker-gateway)"
worker_gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
result=""
reload_attempt=0
while [ "$result" != "0" ]; do
  wait_for_response "$worker_gateway_base_url/basic-open-api/get" "200" "" 3
  result="$?"
  if [ "$result" != "0" ]; then
    if [ "$reload_attempt" -gt "3" ]; then
      log_message "  ERROR: Unable to access API via tyk-worker-gateway (max retry count reached)"
      exit 1
    fi
    reload_attempt=$((reload_attempt+1))
    log_message "  Gateway not returning desired response, attempting hot reload (attempt #$reload_attempt)"
    hot_reload "$worker_gateway_base_url" "$worker_gateway_api_credentials" 
    sleep 2
  fi
done
log_ok  
bootstrap_progress

log_end_deployment

echo -e "\033[2K 
▼ MDCB
  ▽ Multi Data Centre Bridge ($(get_service_image_tag "tyk-mdcb"))
                Licence : $mdcb_licence_days_remaining days remaining
     Dashboard Auth Key : $dashboard_mdcb_user_api_credentials
       Ngrok tunnel URL : $ngrok_mdcb_tunnel_url
  ▽ Worker Gateway ($(get_service_image_tag "tyk-worker-gateway"))
                    URL : $worker_gateway_base_url
        Gateway API Key : $worker_gateway_api_credentials
     Gateway API Header : x-tyk-authorization
  ▽ Worker Gateway Ngrok ($(get_service_image_tag "tyk-worker-gateway-ngrok"))
                    URL : http://tyk-worker-gateway.localhost:8093
        Gateway API Key : $worker_gateway_api_credentials
     Gateway API Header : x-tyk-authorization"
