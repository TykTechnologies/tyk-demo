#!/bin/bash

source scripts/common.sh
deployment="GraphQL Federations"
log_start_deployment

# Setup variables
dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

# Create APIs for Subgraphs and Federation
create_api "deployments/federation/data/apis-users.json" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
bootstrap_progress

create_api "deployments/federation/data/apis-posts.json" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
bootstrap_progress

create_api "deployments/federation/data/apis-notifications.json" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
bootstrap_progress

create_api "deployments/federation/data/apis-supergraph.json" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Federation
  ▽ Supergraph Playground:
                    URL : $gateway_base_url/social-media-federated-graph/playground
  ▽ Users API
                    URL : localhost:4201
                              / 
                              /query
  ▽ Posts API
                    URL : localhost:4202
                              / 
                              /query
  
  ▽ Comments API
                    URL : localhost:4203
                              / 
                              /query
  
  ▽ Notificaitons API
                    URL : localhost:4204
                              / 
                              /query"
