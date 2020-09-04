#!/bin/bash

# Uses the Dashboard Admin API to import API and Policy definitions, using data used to bootstrap the base Tyk deployment

dashboard_base_url="http://tyk-dashboard.localhost:3000"
organisation_1_name=$(cat .context-data/organisation-name)
organisation_2_name=$(cat .context-data/organisation-2-name)
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)

echo "Importing APIs for organisation: $organisation_1_name"
result=$(curl $dashboard_base_url/admin/apis/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat deployments/tyk/data/tyk-dashboard/apis.json)" | jq -r '.Status')
echo "  $result"

echo "Importing Policies for organisation: $organisation_1_name"
result=$(curl $dashboard_base_url/admin/policies/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat deployments/tyk/data/tyk-dashboard/policies.json)" | jq -r '.Status')
echo "  $result"

echo "Importing APIs for organisation: $organisation_2_name"
result=$(curl $dashboard_base_url/admin/apis/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat deployments/tyk/data/tyk-dashboard/apis-organisation-2.json)" | jq -r '.Status')
echo "  $result"

echo "Importing Policies for organisation: $organisation_2_name"
result=$(curl $dashboard_base_url/admin/policies/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$(cat deployments/tyk/data/tyk-dashboard/policies-organisation-2.json)" | jq -r '.Status')
echo "  $result"