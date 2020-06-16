#!/bin/bash

# Uses the Dashboard Admin API to import API and Policy definitions, using data used to bootstrap the base Tyk deployment

dashboard_base_url="http://tyk-dashboard.localhost:3000"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)

echo "Importing APIs"
result=$(curl $dashboard_base_url/admin/apis/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat deployments/tyk/data/tyk-dashboard/apis.json)" | jq -r '.Status')
echo "  $result"

echo "Importing Policies"
result=$(curl $dashboard_base_url/admin/policies/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat deployments/tyk/data/tyk-dashboard/policies.json)" | jq -r '.Status')
echo "  $result"