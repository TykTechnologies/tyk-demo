#!/bin/bash


source scripts/common.sh
deployment="Governance"

log_start_deployment
bootstrap_progress

GOVN_DASHBOARD_BASE_URL="http://tyk-governance-dashboard.localhost:8082"
GOVN_USER_EMAIL="$(jq -r '.email' deployments/governance/data/governance-dashboard/bootstrap.json)"
GOVN_USER_PASSWORD="$(jq -r '.password' deployments/governance/data/governance-dashboard/bootstrap.json)"

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
bootstrap_message=$(echo "$response" | jq -r '.Message')
if [[ $bootstrap_message != "bootstrap successful" ]]; then
    log_message "  Failed"
    echo "ERROR: Failed to bootstrap Governance Dashboard. Response: $response"
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
    echo "ERROR: Failed to bootstrap create agent. Response: $response"
    exit 1
else 
    log_message "  Agent id: $agent_id"
    log_ok
fi
bootstrap_progress


agent_governance_credentials=""

# set agent credentials and recreate the agent container
log_message "Setting Docker environment variable for agent API credentials"
set_docker_environment_value "AGENT_GOVERNANCE_DASHBOARD_API_CREDENTIALS" "$agent_governance_credentials"
set_context_data "1" "governance-dashboard-user" "agent" "api-key" "$agent_governance_credentials"
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
  ▽ Governance Agent ($(get_service_image_tag "tyk-governance-agent"))
             TBC       URL : http://tyk-governance-agent.localhost:5959"
