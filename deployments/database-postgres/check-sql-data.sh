#!/bin/bash

source scripts/common.sh

dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
dashboard_user_api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")
test_api_name=$(cat deployments/database-postgres/data/test-api.json | jq -r .api_definition.name)

echo "Importing an API Definition called \"$test_api_name\" into the Dashboard"

create_api "deployments/database-postgres/data/test-api.json" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"

echo "Querying PostgreSQL for an API called \"$test_api_name\" - expecting result to show 1 row"

$(generate_docker_compose_command) exec -u postgres tyk-postgres sh -c "psql -U postgres -d tyk_analytics -c \"SELECT name FROM tyk_apis WHERE name = '$test_api_name';\""
