#!/bin/bash

source scripts/common.sh
deployment="MDCB"

log_start_deployment
bootstrap_progress

worker_gateway_base_url="http://tyk-worker-gateway.localhost:8084"
dashboard_base_url="http://tyk-dashboard.localhost:3000"

# check MDCB licence defined
log_message "Checking MDCB licence is present"
if ! grep -q "MDCB_LICENCE=" .env
then
  echo "ERROR: MDCB licence missing from Docker environment file. Review 'Setup' steps in deployments/mdcb/README.md."
  exit 1
fi
log_ok
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

# restart containers to use updated MDCB credentials
log_message "Restarting MDCB deployment containers to use updated MDCB user API credentials"
docker-compose \
    -f deployments/tyk/docker-compose.yml \
    -f deployments/mdcb/docker-compose.yml \
    -p tyk-demo \
    --project-directory $(pwd) \
    up -d --no-deps --force-recreate tyk-mdcb tyk-worker-gateway 2> /dev/null
log

# check status of worker Gateway
log_message "Checking status of Worker Gateway"
worker_gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
wait_for_response "$worker_gateway_base_url/basic-open-api/get" "200"

log_end_deployment

echo -e "\033[2K 
▼ MDCB
  ▽ Multi Data Centre Bridge
   API Credentials : $dashboard_mdcb_user_api_credentials
  ▽ Worker Gateway
               URL : $worker_gateway_base_url
   API Credentials : $worker_gateway_api_credentials"