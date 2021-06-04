#!/bin/bash

source scripts/common.sh
deployment="Ngrok for tyk gateway on port 8080"
log_start_deployment
ngrok_ip_api_endpoint="http://localhost:4551/api/tunnels"

log_message "Getting the ngrok allocated IP for tyk-gateway:8080"

access_ip=$(curl --fail --silent --show-error ${ngrok_ip_api_endpoint} | jq ".tunnels[0].public_url" --raw-output)

log_end_deployment
echo -e "\033[2K
▼ Ngrok for tyk gateway on port 8080
  ▽ www-ngrok
                    URL : $access_ip"
