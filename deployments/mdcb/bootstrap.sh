#!/bin/bash

source scripts/common.sh
deployment="MDCB"

log_start_deployment
bootstrap_progress

log_message "Storing container names"
if [ -f .bootstrap/is_docker_compose_v1 ]; then
  set_context_data "container" "mdcb" "1" "name" "tyk-demo_tyk-mdcb_1"
else
  set_context_data "container" "mdcb" "1" "name" "tyk-demo-tyk-mdcb-1"
fi
log_ok
bootstrap_progress

log_message "Setting global variables"
worker_gateway_base_url="http://tyk-worker-gateway.localhost:8084"
dashboard_base_url="http://tyk-dashboard.localhost:3000"
log_ok
bootstrap_progress

# check MDCB licence exists
log_message "Checking MDCB licence exists"
if ! grep -q "MDCB_LICENCE=" .env
then
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
log_message "Creating Dashboard MDCB user"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>> bootstrap.log)
dashboard_mdcb_user_email=$(jq -r '.email_address' deployments/mdcb/data/tyk-dashboard/dashboard-mdcb-user.json)
dashboard_mdcb_user_password=$(jq -r '.password' deployments/mdcb/data/tyk-dashboard/dashboard-mdcb-user.json)
dashboard_mdcb_user_api_response=$(curl $dashboard_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @deployments/mdcb/data/tyk-dashboard/dashboard-mdcb-user.json 2>> bootstrap.log \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard_mdcb_user_id=$(echo $dashboard_mdcb_user_api_response | jq -r '.id')
dashboard_mdcb_user_api_credentials=$(echo $dashboard_mdcb_user_api_response | jq -r '.api_key')
log_ok
bootstrap_progress

# set MDCB credentials and recreate the MDCB container
log_message "Setting MDCB user API crednetials"
set_docker_environment_value "MDCB_USER_API_CREDENTIALS" "$dashboard_mdcb_user_api_credentials"
log_ok
bootstrap_progress

# recreate containers to use updated MDCB credentials
log_message "Recreating MDCB deployment containers to use updated MDCB user API credentials"
if [ -f .bootstrap/is_docker_compose_v1 ]; then
  docker-compose \
      -f deployments/tyk/docker-compose.yml \
      -f deployments/mdcb/docker-compose.yml \
      -p tyk-demo \
      --project-directory $(pwd) \
      up -d --no-deps --force-recreate tyk-mdcb tyk-worker-gateway 2> /dev/null
else
  docker compose \
      -f deployments/tyk/docker-compose.yml \
      -f deployments/mdcb/docker-compose.yml \
      -p tyk-demo \
      --project-directory $(pwd) \
      --env-file $(pwd)/.env \
      up -d --no-deps --force-recreate tyk-mdcb tyk-worker-gateway 2> /dev/null
fi
if [ "$?" != 0 ]; then
  echo "Error occurred when recreating MDCB deployment containers"
  exit 1
fi
log_ok
bootstrap_progress

# verify MDCB container is running
log_message "Checking status of MDCB container"
mdcb_status=$(docker ps -a --filter "name=$(get_context_data "container" "mdcb" "1" "name")" --format "{{.Status}}")
log_message "  MDCB container status is: $mdcb_status"
if [[ $mdcb_status != Up* ]]
then
  log_message "  ERROR: MDCB container not in desired status. Exiting."
  log_message "  Suggest checking MDCB container log for more information. Perhaps the MDCB licence has expired?"
  exit 1
fi
log_ok
bootstrap_progress

# check status of worker Gateway
log_message "Checking status of Worker Gateway"
worker_gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
result=""
while [ "$result" != "0" ]
do
  wait_for_response "$worker_gateway_base_url/basic-open-api/get" "200" "" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    log_message "  Gateway not returning desired response, attempting hot reload"
    hot_reload "$worker_gateway_base_url" "$worker_gateway_api_credentials" 
    sleep 2
  fi
done

log_end_deployment

echo -e "\033[2K 
▼ MDCB
  ▽ Multi Data Centre Bridge
                Licence : $mdcb_licence_days_remaining days remaining
   Dash API Credentials : $dashboard_mdcb_user_api_credentials
  ▽ Worker Gateway
                    URL : $worker_gateway_base_url
        API Credentials : $worker_gateway_api_credentials
       API AuthZ Header : x-tyk-authorization"
