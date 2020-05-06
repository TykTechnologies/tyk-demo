#!/bin/bash

dashboard_base_url="http://localhost:3000"
dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)

echo "Exporting APIs"
curl $dashboard_base_url/api/apis?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" \
  | jq '.' \
  > tyk/data/tyk-dashboard/apis.json

echo "Exporting Policies"
curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" \
  | jq '.' \
  > tyk/data/tyk-dashboard/policies.json