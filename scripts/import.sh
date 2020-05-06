#!/bin/bash

dashboard_base_url="http://localhost:3000"
dashboard_admin_api_credentials=$(cat tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)

echo "Importing APIs"
result=$(curl $dashboard_base_url/admin/apis/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat tyk/data/tyk-dashboard/apis.json)" \
  | jq -r '.Status')
echo "  $result"

echo "Importing Policies"
result=$(curl $dashboard_base_url/admin/policies/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat tyk/data/tyk-dashboard/policies.json)" \
  | jq -r '.Status')
echo "  $result"