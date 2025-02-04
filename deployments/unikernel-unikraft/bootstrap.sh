#!/bin/bash

source scripts/common.sh

deployment="Unikernel Unikraft"

dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

run_kraft_cloud() {
  local command=$1
  kraft cloud --metro "$UKC_METRO" --token "$UKC_TOKEN" $command
}

log_start_deployment

log_message "Checking for Unikraft CLI (kraft)"
if ! command -v kraft &> /dev/null
then
  echo "ERROR: Unikraft CLI (kraft) could not be found. Please install it before proceeding."
  exit 1
fi
log_ok
bootstrap_progress

log_message "Checking if MDCB deployment is available"
if ! deployment_is_bootstrapped "mdcb"; then
  echo "ERROR: MDCB deployment is not available. Please ensure it is bootstrapped."
  exit 1
fi
log_ok
bootstrap_progress

log_message "Resetting local deployment .env file"
deployment_env_file="deployments/unikernel-unikraft/unikraft/.env"
> "$deployment_env_file"
log_ok
bootstrap_progress

log_message "Getting MDCB config"
mdcb_url=$(get_context_data "1" "ngrok" "mdcb" "url")
mdcb_apikey=$(get_context_data "1" "dashboard-user" "mdcb" "api-key")
if [[ -z "$mdcb_url" ]]; then
  echo "ERROR: MDCB Ngrok URL not found. Ensure that Tyk Demo is configured to use Ngrok."
  exit 1
fi
log_message "  MDCB URL: $mdcb_url"
if [[ -z "$mdcb_apikey" ]]; then
  echo "ERROR: MDCB API Key not found. Ensure that Tyk Demo deployment includes MDCB."
  exit 1
fi
log_message "  MDCB API key: $mdcb_apikey"
log_ok
bootstrap_progress

log_message "Writing MDCB config to local deployment .env file"
echo "MDCB_URL=$mdcb_url" >> "$deployment_env_file"
echo "MDCB_KEY=$mdcb_apikey" >> "$deployment_env_file"
log_ok
bootstrap_progress

log_message "Loading Unikraft Cloud config from global .env file"
UKC_METRO=$(grep -E '^UKC_METRO=' ".env" | cut -d '=' -f2)
UKC_TOKEN=$(grep -E '^UKC_TOKEN=' ".env" | cut -d '=' -f2)
if [[ -z "$UKC_METRO" ]]; then
  echo "ERROR: UKC_METRO is missing in the .env file."
  exit 1
fi
if [[ -z "$UKC_TOKEN" ]]; then
  echo "ERROR: UKC_TOKEN is missing in the .env file."
  exit 1
fi
log_message "  UKC_METRO: $UKC_METRO"
obfuscated_token=$(echo "$UKC_TOKEN" | sed -r 's/(.{4})(.*)/\1****/')
log_message "  UKC_TOKEN: $obfuscated_token"
log_ok
bootstrap_progress

log_message "Importing example API"
unikraft_api_file="deployments/unikernel-unikraft/data/apis/api-oas-a06c702ac2a74b594ba95709a35e7823.json"
create_api "$unikraft_api_file" "$dashboard_user_api_key"
log_ok
bootstrap_progress

log_message "Starting Unikraft deployment (may take a few minutes on first run, to generate build assets)"
kraft_output=$(
  cd deployments/unikernel-unikraft/unikraft && 
  run_kraft_cloud "compose up --detach --env-file .env"
)
log_message "$kraft_output"
log_ok
bootstrap_progress

gateway_json_config=$(run_kraft_cloud "instance get tyk-gateway -o json")
unikraft_gateway_url=$(echo "$gateway_json_config" | jq -r '.[].fqdn')

log_end_deployment

echo -e "\033[2K
▼ Unikernel - Unikraft
  ▽ Unikraft Cloud
            Gateway URL : https://$unikraft_gateway_url
        Example API URL : https://$unikraft_gateway_url/unikraft/get"