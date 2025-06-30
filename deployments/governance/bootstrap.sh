#!/bin/bash


source scripts/common.sh
deployment="Governance"

log_start_deployment
bootstrap_progress

GOVN_DASHBOARD_BASE_URL="http://tyk-governance-dashboard.localhost:8082"
GOVN_USER_EMAIL=$(jq -r '.email' deployments/governance/data/governance-dashboard/bootstrap.json)
GOVN_USER_PASSWORD=$(jq -r '.password' deployments/governance/data/governance-dashboard/bootstrap.json)
DASHBOARD_ADMIN_API_CREDENTIALS=$(jq -r '.admin_secret' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)
dashboard_base_url="http://tyk-dashboard.localhost:3000"

# check that yq is available
command -v yq >/dev/null 2>&1 || { echo >&2 "ERROR: yq is required, but it's not installed. Please install yq and try again."; exit 1; }

log_message "Checking Governance licence expiry"
licence_days_remaining=0
check_licence_expiry "GOVERNANCE_LICENSE"; expiry_check=$?
if [[ "$expiry_check" -eq "1" ]]; then
    # The error message is displayed by the check_licence_expiry function itself
    exit 1
fi
bootstrap_progress

log_message "Bootstrapping Governance Dashboard"
response=$(curl $GOVN_DASHBOARD_BASE_URL/api/bootstrap/ -s \
    -H "X-Admin-Secret: 12345" \
    -H "Content-Type: application/json" \
    -d @deployments/governance/data/governance-dashboard/bootstrap.json 2>> logs/bootstrap.log)
# validate success
GOVN_BOOTSTRAP_SUCCESS_MESSAGE="bootstrap successful"
bootstrap_message=$(echo "$response" | jq -r '.Message')
if [[ $bootstrap_message != $GOVN_BOOTSTRAP_SUCCESS_MESSAGE ]]; then
    log_message "  Failed"
    echo "ERROR: Failed to bootstrap Governance Dashboard. Expected "$GOVN_BOOTSTRAP_SUCCESS_MESSAGE" message. Response: $response"
    exit 1
else 
    govn_user_api_token=$(echo "$response" | jq -r '.api_token')
    log_message "  User API token: $govn_user_api_token"
    log_ok
fi
bootstrap_progress

log_message "Creating Agent"
response=$(curl $GOVN_DASHBOARD_BASE_URL/api/agents/ -s \
    -H "X-API-Key: $govn_user_api_token" \
    -H "Content-Type: application/json" \
    -d @deployments/governance/data/governance-dashboard/agent.json 2>> logs/bootstrap.log)
agent_id=$(echo "$response" | jq -r '.id')
if [[ $agent_id == "" ]]; then
    log_message "  Failed"
    echo "ERROR: Failed to create agent. Expected agent id. Response: $response"
    exit 1
else 
    log_message "  Agent id: $agent_id"
    log_ok
fi
bootstrap_progress


log_message "Creating Agent Token"
response=$(curl $GOVN_DASHBOARD_BASE_URL/api/auth/token/ -s \
    -H "X-API-Key: $govn_user_api_token" \
    -H "Content-Type: application/json" \
    --data-raw "{ \"agent_id\": \"$agent_id\" }" 2>> logs/bootstrap.log)

govn_agent_token=$(echo "$response" | jq -r '.token')
if [[ $govn_agent_token == "" ]]; then
    log_message "  Failed"
    echo "ERROR: Failed to create agent token. Response: $response"
    exit 1
else 
    log_message "  Agent token: $govn_agent_token"
    log_ok
fi
bootstrap_progress

log_message "Creating Governance User in Tyk Dashboard"
create_dashboard_user "deployments/governance/data/governance-dashboard/tyk-dashboard-agent-user.json" "$DASHBOARD_ADMIN_API_CREDENTIALS" "1" "100"
dashboard_agent_token=$(get_context_data "1" "dashboard-user" "100" "api-key")
if [[ $dashboard_agent_token == "" ]]; then
    log_message "  Failed"
    echo "ERROR: Failed to create Governance Agent user in Tyk Dashboard."
    exit 1
else 
    log_message "  Dashboard Agent User Token: $dashboard_agent_token"
    log_ok
fi

log_message "Updating agent configuration file"
yq -i ".instances[0].config.auth = \"$dashboard_agent_token\"" deployments/governance/volumes/governance-agent/config.yaml
yq -i ".governanceDashboard.auth.token = \"$govn_agent_token\"" deployments/governance/volumes/governance-agent/config.yaml
yq -i ".licenseKey = \"$govn_agent_token\"" deployments/governance/volumes/governance-agent/config.yaml
log_ok
bootstrap_progress

log_message "Recreating governance agent Service (to use updated config file)"
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate tyk-governance-agent 2> /dev/null
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K 
▼ Governance
  ▽ Governance Dashboard ($(get_service_image_tag "tyk-governance-dashboard"))
                Licence : $licence_days_remaining days remaining
                    URL : $GOVN_DASHBOARD_BASE_URL
               Username : $GOVN_USER_EMAIL
               Password : $GOVN_USER_PASSWORD
              API Token : $govn_user_api_token
  ▽ Governance Agent ($(get_service_image_tag "tyk-governance-agent"))
             TBC       URL : http://tyk-governance-agent.localhost:5959
   Tyk Dash Agent Token : $dashboard_agent_token"
