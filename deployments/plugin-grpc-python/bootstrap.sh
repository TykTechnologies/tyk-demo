#!/bin/bash

source scripts/common.sh
deployment="Python gRPC Plugin"

log_start_deployment
bootstrap_progress

# Setup variables
dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

# Create custom-auth API for Python gRCP
create_api "deployments/plugin-grpc-python/data/apis-python_grpc.json" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
bootstrap_progress

# Check that the API has loaded
log_message "Waiting for API availability"
for file in deployments/plugin-grpc-python/data/*; do
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
for file in deployments/plugin-grpc-python/data/keys/bearer-token/*; do
  if [[ -f $file ]]; then
    create_bearer_token "$file" "$gateway_api_credentials"
    bootstrap_progress        
  fi
done

log_message "Set environment variable for coprocess gRPC server"
set_docker_environment_value "TYK_GW_COPROCESSOPTIONS_COPROCESSGRPCSERVER" "tcp://tyk-python-grpc-server:50051"
log_ok

log_message "Restart Tyk Gateway to pick up env var change"
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate tyk-gateway 1>/dev/null 2>>logs/bootstrap.log
log_ok

log_end_deployment

echo -e "\033[2K
▼ Python gRPC Plugin
  ▽ gRPC Server
                    URL : http://localhost:50051
  ▽ Example API (custom Python gRPC auth plugin for HMAC signed authentication key)
                    URL : http://localhost:8080/grpc-custom-auth/
            HMAC secret : secret
         HMAC algorithm : hmac-sha512
            HMAC key ID : eyJvcmciOiI1ZTlkOTU0NGExZGNkNjAwMDFkMGVkMjAiLCJpZCI6ImdycGNfaG1hY19rZXkiLCJoIjoibXVybXVyNjQifQ==
"
