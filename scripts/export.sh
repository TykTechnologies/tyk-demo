#!/bin/bash

dashboard_base_url="http://localhost:3000"
dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)

echo "Exporting APIs"
api_data=$(cat tyk/data/tyk-dashboard/import-template-apis-base.json)
api_ids_to_export=$(curl $dashboard_base_url/api/apis?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" | \
  jq --raw-output '.apis[].api_definition.api_id')
for api_id in $api_ids_to_export
do
  api_definition=$(curl $dashboard_base_url/api/apis/$api_id -s \
    -H "Authorization:$dashboard_user_api_credentials")
  echo "  $(echo "$api_definition" | jq -r .api_definition.name)"
  api_data=$(echo $api_data | jq --argjson api_definition "$api_definition" '.apis += [$api_definition]')
done
echo $api_data | jq '.' > tyk/data/tyk-dashboard/apis.json

echo "Exporting Policies"
policy_data=$(cat tyk/data/tyk-dashboard/import-template-policies-base.json)
policy_ids_to_export=$(curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" | \
  jq --raw-output '.Data[]._id')
for policy_id in $policy_ids_to_export
do
  policy_definition=$(curl $dashboard_base_url/api/portal/policies/$policy_id -s \
    -H "Authorization:$dashboard_user_api_credentials")
  echo "  $(echo "$policy_definition" | jq -r .name)"
  policy_data=$(echo $policy_data | jq --argjson policy_definition "$policy_definition" '.Data += [$policy_definition]')
done
echo $policy_data | jq '.' > tyk/data/tyk-dashboard/policies.json