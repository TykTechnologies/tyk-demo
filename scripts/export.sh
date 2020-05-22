#!/bin/bash

# Uses the Dashboard API to export API and Policy definitions, overwriting data used to bootstrap the base Tyk deployment

dashboard_base_url="http://localhost:3000"
dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)

echo "Exporting APIs"
curl $dashboard_base_url/api/apis?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" \
  | jq '.' \
  > deployments/tyk/data/tyk-dashboard/apis.json
cat deployments/tyk/data/tyk-dashboard/apis.json | jq --raw-output '.apis[].api_definition.name' | while read api_name
do
  echo "  $api_name"
done

echo "Exporting Policies"
curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" \
  | jq '.' \
  > deployments/tyk/data/tyk-dashboard/policies.json
cat deployments/tyk/data/tyk-dashboard/policies.json | jq --raw-output '.Data[].name' | while read policy_name
do
  echo "  $policy_name"
done