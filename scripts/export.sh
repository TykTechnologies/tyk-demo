#!/bin/bash

# Uses the Dashboard API to export API and Policy definitions, overwriting data used to bootstrap the base Tyk deployment

dashboard_base_url="http://tyk-dashboard.localhost:3000"

organisation_1_name=$(cat .context-data/organisation-name)
dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)

organisation_2_name=$(cat .context-data/organisation-2-name)
dashboard_user_organisation_2_api_credentials=$(cat .context-data/dashboard-user-organisations-2-api-credentials)

echo "Exporting APIs for organisation: $organisation_1_name"
curl $dashboard_base_url/api/apis?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" \
  | jq '.' \
  > deployments/tyk/data/tyk-dashboard/apis.json
cat deployments/tyk/data/tyk-dashboard/apis.json | jq --raw-output '.apis[].api_definition.name' | while read api_name
do
  echo "  $api_name"
done

echo "Exporting Policies for organisation: $organisation_1_name"
curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" \
  | jq '.' \
  > deployments/tyk/data/tyk-dashboard/policies.json
cat deployments/tyk/data/tyk-dashboard/policies.json | jq --raw-output '.Data[].name' | while read policy_name
do
  echo "  $policy_name"
done

echo "Exporting APIs for organisation: $organisation_2_name"
curl $dashboard_base_url/api/apis?p=-1 -s \
  -H "Authorization:$dashboard_user_organisation_2_api_credentials" \
  | jq '.' \
  > deployments/tyk/data/tyk-dashboard/apis-organisation-2.json
cat deployments/tyk/data/tyk-dashboard/apis-organisation-2.json | jq --raw-output '.apis[].api_definition.name' | while read api_name
do
  echo "  $api_name"
done

echo "Exporting Policies for organisation: $organisation_2_name"
curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_organisation_2_api_credentials" \
  | jq '.' \
  > deployments/tyk/data/tyk-dashboard/policies-organisation-2.json
cat deployments/tyk/data/tyk-dashboard/policies-organisation-2.json | jq --raw-output '.Data[].name' | while read policy_name
do
  echo "  $policy_name"
done
