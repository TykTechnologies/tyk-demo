#!/bin/bash

source scripts/common.sh

deployment="Unikernel Unikraft"

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

log_message "Creating/resetting .env file"
deployment_env_file="deployments/unikernel-unikraft/unikraft/.env"
> "$deployment_env_file"
log_ok
bootstrap_progress

log_message "Writing deployment environtment variables"
mdcb_apikey=$(get_context_data "1" "dashboard-user" "mdcb" "api-key")
mdcb_url=$(get_context_data "1" "ngrok" "mdcb" "url")
log_message "  MDCB URL: $mdcb_url"
log_message "  MDCB API key: $mdcb_apikey"
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

log_message "Starting Unikraft deployment"
(
  cd /Users/davidgarvey/git/tyk-demo/deployments/unikernel-unikraft/unikraft && 
  kraft cloud --metro "$UKC_METRO" --token "$UKC_TOKEN" compose up --detach --env-file .env
)
log_ok
bootstrap_progress
