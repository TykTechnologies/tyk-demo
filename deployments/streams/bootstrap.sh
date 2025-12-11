#!/bin/bash

source scripts/common.sh
deployment="streams"

log_start_deployment
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
gateway_base_url="http://tyk-gateway.localhost:8080"
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

log_message "Importing Streams Master Data APIs"

log_message "Creating Streams Master Data Consumer Filtered HTTP API"
create_api "deployments/streams/data/tyk-dashboard/apis/api-streams-master-data-consumer-filtered-http.json" "$dashboard_user_api_key" 
bootstrap_progress

log_message "Creating Streams Master Data Consumer Filtered API"
create_api "deployments/streams/data/tyk-dashboard/apis/api-streams-master-data-consumer-filtered.json" "$dashboard_user_api_key" 
bootstrap_progress

log_message "Creating Streams Master Data Consumer JSON HTTP API"
create_api "deployments/streams/data/tyk-dashboard/apis/api-streams-master-data-consumer-json-http.json" "$dashboard_user_api_key"
bootstrap_progress

log_message "Creating Streams Master Data Consumer JSON API"
create_api "deployments/streams/data/tyk-dashboard/apis/api-streams-master-data-consumer-json.json" "$dashboard_user_api_key"
bootstrap_progress

log_message "Creating Streams Master Data Consumer XML HTTP API"
create_api "deployments/streams/data/tyk-dashboard/apis/api-streams-master-data-consumer-xml-http.json" "$dashboard_user_api_key"
bootstrap_progress

log_message "Creating Streams Master Data Consumer XML API"
create_api "deployments/streams/data/tyk-dashboard/apis/api-streams-master-data-consumer-xml.json" "$dashboard_user_api_key"
bootstrap_progress

log_message "Creating Streams Master Data Producer API"
create_api "deployments/streams/data/tyk-dashboard/apis/api-streams-master-data.json" "$dashboard_user_api_key"
bootstrap_progress


log_end_deployment

echo -e "\033[2K
▼ Streams
 
  ▽ ERP JSON
                    URL : http://localhost:8001/erp/json/receive
  ▽ ERP XML
                    URL : http://localhost:8002/erp/xml/receive
  ▽ ERP Filtered
                    URL : http://localhost:8003/erp/filtered/receive            
  ▽ Master Data UI
                    URL : http://localhost:8888"
