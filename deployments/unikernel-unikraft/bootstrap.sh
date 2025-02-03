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

log_message "Creating/resetting .env file"
env_file="deployments/unikernel-unikraft/.env"
> "$env_file"
log_ok
bootstrap_progress

log_message "Getting MDCB variables"
mdcb_apikey=$(get_context_data "1" "dashboard-user" "mdcb" "api-key")
mdcb_url=$(get_context_data "1" "ngrok" "mdcb" "url")
log_message "  MDCB API key: $mdcb_apikey"
log_message "  MDCB URL: $mdcb_url"
