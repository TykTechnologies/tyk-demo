#!/bin/bash

source scripts/common.sh
deployment="SLO Prometheus Grafana"
log_start_deployment

# Setup variables
dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

# Create APIs for SLO Demo
create_api "deployments/slo-prometheus-grafana/data/apis/httpstatus.json" "$dashboard_user_api_key"
bootstrap_progress

create_api "deployments/slo-prometheus-grafana/data/apis/httpbin.json" "$dashboard_user_api_key"
bootstrap_progress

# Stopping tyk-pump service
log_message "Stopping the tyk-pump service (from Tyk deployment), to prevent it consuming analytics data intended for this deployment's Pump"
eval $(generate_docker_compose_command) stop tyk-pump 2> /dev/null
if [ "$?" != 0 ]; then
  echo "Error stopping Pump service tyk-pump"
  exit 1
fi
log_ok
bootstrap_progress

# Verify tyk-pump service is stopped
log_message "Confirming that tyk-pump service is stopped"
service_process=$(eval $(generate_docker_compose_command) top tyk-pump)
if [ "$service_process" != "" ]; then
  log_message "  ERROR: tyk-pump process has not stopped. Exiting."
  exit 1
fi
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ SLO Prometheus Grafana
  ▽ Grafana
                    URL : http://localhost:3020/
               Username : admin
               Password : admin
  ▽ Prometheus
                    URL : http://localhost:9090/
  ▽ Tyk Gateway
        HTTPBin API URL : http://localhost:8080/httpbin/
     HTTPStatus API URL : http://localhost:8080/status/
  ▽ Tyk Pump
       Health Check URL : http://localhost:8091/health
   Metrics Endpoint URL : http://localhost:8092/metrics"