#!/bin/bash

# Uses the Dashboard API to export API and Policy definitions, overwriting data used to bootstrap the base Tyk deployment

dashboard_base_url="http://tyk-dashboard.localhost:3000"

organisation_1_name=$(cat .context-data/organisation-name)
dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)

organisation_2_name=$(cat .context-data/organisation-2-name)
dashboard_user_organisation_2_api_credentials=$(cat .context-data/dashboard-user-organisations-2-api-credentials)

echo "Exporting APIs for organisation: $organisation_1_name"
index=1
apis1=$(curl $dashboard_base_url/api/apis?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" \
  | jq '.')
echo "$apis1" | jq --raw-output '.apis[].api_definition.id' | while read api_id
do
  api=$(curl $dashboard_base_url/api/apis/$api_id -s \
    -H "Authorization:$dashboard_user_api_credentials" \
    | jq '.')
  echo "  $(jq --raw-output '.api_definition.name' <<< $api)"
  echo "$api" > "export/1/api-$index.json"
  index=$((index+1))
done

echo "Exporting Policies for organisation: $organisation_1_name"
index=1
policies1=$(curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" \
  | jq '.')
echo "$policies1" | jq --raw-output '.Data[]._id' | while read policy_id
do
  policy=$(curl $dashboard_base_url/api/portal/policies/$policy_id -s \
    -H "Authorization:$dashboard_user_api_credentials" \
    | jq '.')
  echo "  $(jq --raw-output '.name' <<< $policy)"
  echo "$policy" > "export/1/policy-$index.json"
  index=$((index+1))
done

echo "Exporting APIs for organisation: $organisation_2_name"
index=1
apis2=$(curl $dashboard_base_url/api/apis?p=-1 -s \
  -H "Authorization:$dashboard_user_organisation_2_api_credentials" \
  | jq '.')
echo "$apis2" | jq --raw-output '.apis[].api_definition.id' | while read api_id
do
  api=$(curl $dashboard_base_url/api/apis/$api_id -s \
    -H "Authorization:$dashboard_user_organisation_2_api_credentials" \
    | jq '.')
  echo "  $(jq --raw-output '.api_definition.name' <<< $api)"
  echo "$api" > "export/2/api-$index.json"
  index=$((index+1))
done

echo "Exporting Policies for organisation: $organisation_2_name"
index=1
policies2=$(curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_organisation_2_api_credentials" \
  | jq '.')
echo "$policies2" | jq --raw-output '.Data[]._id' | while read policy_id
do
  policy=$(curl $dashboard_base_url/api/portal/policies/$policy_id -s \
    -H "Authorization:$dashboard_user_organisation_2_api_credentials" \
    | jq '.')
  echo "  $(jq --raw-output '.name' <<< $policy)"
  echo "$policy" > "export/2/policy-$index.json"
  index=$((index+1))
done

# echo "Exporting APIs for organisation: $organisation_2_name"
# curl $dashboard_base_url/api/apis?p=-1 -s \
#   -H "Authorization:$dashboard_user_organisation_2_api_credentials" \
#   | jq '.' \
#   > deployments/tyk/data/tyk-dashboard/apis-organisation-2.json
# cat deployments/tyk/data/tyk-dashboard/apis-organisation-2.json | jq --raw-output '.apis[].api_definition.name' | while read api_name
# do
#   echo "  $api_name"
# done

# echo "Exporting Policies for organisation: $organisation_2_name"
# curl $dashboard_base_url/api/portal/policies?p=-1 -s \
#   -H "Authorization:$dashboard_user_organisation_2_api_credentials" \
#   | jq '.' \
#   > deployments/tyk/data/tyk-dashboard/policies-organisation-2.json
# cat deployments/tyk/data/tyk-dashboard/policies-organisation-2.json | jq --raw-output '.Data[].name' | while read policy_name
# do
#   echo "  $policy_name"
# done
