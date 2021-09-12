#!/bin/bash

# Uses the Dashboard API to export API and Policy definitions, overwriting data used to bootstrap the base Tyk deployment

dashboard_base_url="http://tyk-dashboard.localhost:3000"

declare -a data_groups=("1" "2")
declare -a organisation_names=("$(cat .context-data/1-organisation-1-name)" "$(cat .context-data/2-organisation-1-name)")
declare -a dashboard_keys=("$(cat .context-data/1-dashboard-user-1-api-key)" "$(cat .context-data/2-dashboard-user-1-api-key)")

index=0
for data_group in "${data_groups[@]}"; do\
  echo "Exporting APIs for organisation: ${organisation_names[$index]}"
  apis=$(curl $dashboard_base_url/api/apis?p=-1 -s \
    -H "Authorization:${dashboard_keys[$index]}" \
    | jq -c '.apis[]')
  file_count=1
  while read -r api; do
    if [[ "$api" != "" ]]; then
      echo "  $(jq -r '.api_definition.name' <<< $api)"
      echo "$api" | jq '.' > "deployments/tyk/data/tyk-dashboard/${data_groups[$index]}/apis/api-$file_count.json"
      file_count=$((file_count+1))
    fi 
  done <<< "$apis"

  echo "Exporting Policies for organisation: ${organisation_names[$index]}"
  policies=$(curl $dashboard_base_url/api/portal/policies?p=-1 -s \
    -H "Authorization:${dashboard_keys[$index]}" \
    | jq -c '.Data[]')
  echo "$policies" > "test-$index.json"
  file_count=1
  while read -r policy; do
    if [[ "$policy" != "" ]]; then
      echo "  $(jq -r '.name' <<< $policy)"
      echo "$policy" | jq '.' > "deployments/tyk/data/tyk-dashboard/${data_groups[$index]}/policies/policy-$file_count.json"
      file_count=$((file_count+1))
    fi
  done <<< "$policies"
  
  index=$((index+1))
done