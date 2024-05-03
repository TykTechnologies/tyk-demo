#!/bin/bash

source scripts/common.sh
deployment="Python-gRPC-Server"

log_start_deployment
bootstrap_progress

# Setup variables
dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

# Create custom-auth API for Python gRCP
create_api "deployments/python-grpc-server/data/apis-python_grpc.json" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
bootstrap_progress

# Check that the API has loaded
log_message "Waiting for API availability"
for file in deployments/python-grpc-server/data/*; do
  if [[ -f $file ]]; then
    target_api_id=$(cat $file | jq '.api_definition.api_id' --raw-output)
    wait_for_api_loaded "$target_api_id" "$gateway_base_url" "$gateway_api_credentials"
    bootstrap_progress        
  fi
done
bootstrap_progress        
log_ok

# Keys - bearer hmac
log_message "Creating Bearer Tokens"
for file in deployments/python-grpc-server/data/keys/bearer-token/*; do
  if [[ -f $file ]]; then
    create_bearer_token "$file" "$gateway_api_credentials"
    bootstrap_progress        
  fi
done

log_end_deployment

echo -e "\033[2K
▼ Python gRPC Server
  ▽ gRPC Server
                    URL : http://localhost:50051
  ▽ Example API (custom Python gRPC auth plugin for HMAC signed authentication key)
                    URL : http://localhost:8080/grpc-custom-auth/
            HMAC secret : secret
         HMAC algorithm : hmac-sha512
            HMAC key ID : eyJvcmciOiI1ZTlkOTU0NGExZGNkNjAwMDFkMGVkMjAiLCJpZCI6ImdycGNfaG1hY19rZXkiLCJoIjoibXVybXVyNjQifQ==
"
