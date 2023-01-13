#!/bin/bash

source scripts/common.sh
deployment="Kafka"
log_start_deployment

# Setup variables
dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

# Create APIs for Kafka UDG
create_api "deployments/kafka/data/apis/kafka_redpanda.json" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
bootstrap_progress

bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Kakfa
  ▽ Redpanda Console
                    URL : http://localhost:8090/
  ▽ Broker Addresses
                    PLAINTEXT://redpanda:29092
                    OUTSIDE://localhost:9092"