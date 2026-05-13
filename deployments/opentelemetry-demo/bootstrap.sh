#!/bin/bash

source scripts/common.sh
deployment="OpenTelemetry Demo"
log_start_deployment
bootstrap_progress

# Set required global variables for API creation
dashboard_base_url="http://tyk-dashboard.localhost:3000"
gateway_base_url="http://tyk-gateway.localhost:8080"
log_message "Setting global variables"
log_ok
bootstrap_progress

# Get the dashboard user API key from the tyk deployment context
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")

if [ -z "$dashboard_user_api_key" ]; then
  log_message "ERROR: Could not get Dashboard user API key. Make sure the tyk deployment is bootstrapped first."
  exit 1
fi

# Create APIs using Dashboard API
log_message "Creating OpenTelemetry Demo APIs"
api_count=0
for file in ./deployments/opentelemetry-demo/apps/*.json; do
  if [[ -f $file ]]; then
    api_name=$(jq -r '.api_definition.name // "Unknown"' "$file")
    log_message "  Creating API: $api_name"
    
    create_api "$file" "$dashboard_user_api_key"
    if [ $? -eq 0 ]; then
      api_count=$((api_count + 1))
      bootstrap_progress
    else
      echo "ERROR: Failed to create API from $file"
      exit 1
    fi
  fi
done
log_message "  Created $api_count APIs"
log_ok
bootstrap_progress

# Wait for OpenTelemetry services to be ready
log_message "Waiting for OpenTelemetry services to be ready"
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
  # Check if the frontend container is running and healthy
  if docker ps --filter "name=otel-demo-frontend" --filter "status=running" --format "{{.Names}}" | grep -q "otel-demo-frontend"; then
    # Try to access the frontend through the gateway (which should proxy to the frontend)
    if curl -f -s http://localhost:8080 >/dev/null 2>&1; then
      break
    fi
  fi
  
  sleep 5
  attempt=$((attempt + 1))
  bootstrap_progress
done

if [ $attempt -eq $max_attempts ]; then
  log_message "OpenTelemetry services may still be starting up"
else
  log_message "OpenTelemetry services are ready"
fi
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ OpenTelemetry Demo
     OpenTelemetry Demo UI : http://localhost:8085
                 Jaeger UI : http://localhost:8085/jaeger/ui
                Grafana UI : http://localhost:8085/grafana/
         Load Generator UI : http://localhost:8085/loadgen/
             Feature Flags : http://localhost:8085/feature/
"