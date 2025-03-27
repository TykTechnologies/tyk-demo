#!/bin/bash

# Uses the Dashboard API to export API and Policy definitions, overwriting data used to bootstrap the base Tyk deployment

source scripts/common.sh
dashboard_base_url="http://tyk-dashboard.localhost:3000"

declare -a data_groups=("1" "2")
declare -a organisation_names=()
declare -a dashboard_keys=()

# Populate organisation names and dashboard keys
for group in "${data_groups[@]}"; do
  organisation_names+=("$(get_context_data "$group" "organisation" "1" "name")")
  dashboard_keys+=("$(get_context_data "$group" "dashboard-user" "1" "api-key")")
done

# Loop through each data group
for index in "${!data_groups[@]}"; do
  echo "Exporting APIs for organisation: ${organisation_names[$index]}"

  # Fetch and process APIs
  apis=$(curl -s -H "Authorization:${dashboard_keys[$index]}" "$dashboard_base_url/api/apis?p=-1" | jq -c '.apis[]')
  while IFS= read -r api; do
    [[ -z "$api" ]] && continue

    api_is_oas=$(jq -r '.api_definition.is_oas' <<< "$api")
    api_name=$(jq -r '.api_definition.name' <<< "$api")
    api_id=$(jq -r '.api_definition.api_id' <<< "$api")
    api_file_name="api-$api_id.json"

    echo "  $api_name"

    # Fetch full API definition if OAS
    if [[ "$api_is_oas" == "true" ]]; then
      # Fetch OAS-style API definition
      api=$(curl -s -H "Authorization:${dashboard_keys[$index]}" "$dashboard_base_url/api/apis/oas/$api_id")
      # Remove the dbId field, as this changes every time the data is exported, resulting in unnecessary modifications
      api=$(echo "$api" | jq 'del(."x-tyk-api-gateway".info.dbId)')
    else
      # Remove these fields, as they change every time the data is exported, resulting in unnecessary modifications
      api=$(echo "$api" | jq 'del(.updated_at, .api_definition.id, .api_definition.graphql.last_schema_update)')
      # Use placeholder value for any webhook ids, as these change on import, resulting in unnecessary modifications
      api=$(echo "$api" | jq '.hook_references[].hook.id = "000000000000000000000000"')
      api=$(echo "$api" | jq '.api_definition.event_handlers.events |= with_entries(.value |= map(if .handler_meta.webhook_id then (.handler_meta.webhook_id = "000000000000000000000000" | .handler_meta.id = "000000000000000000000000") else . end))')
    fi

    mkdir -p "deployments/tyk/data/tyk-dashboard/${data_groups[$index]}/apis"
    echo "$api" > "deployments/tyk/data/tyk-dashboard/${data_groups[$index]}/apis/$api_file_name"
  done <<< "$apis"

  echo "Exporting Policies for organisation: ${organisation_names[$index]}"

  # Fetch and process Policies
  policies=$(curl -s -H "Authorization:${dashboard_keys[$index]}" "$dashboard_base_url/api/portal/policies?p=-1" | jq -c '.Data | reverse | .[]')
  while IFS= read -r policy; do
    [[ -z "$policy" ]] && continue

    policy_id=$(jq -r '._id' <<< "$policy")
    echo "  $(jq -r '.name' <<< "$policy")"

    mkdir -p "deployments/tyk/data/tyk-dashboard/${data_groups[$index]}/policies"
    echo "$policy" | jq '.' > "deployments/tyk/data/tyk-dashboard/${data_groups[$index]}/policies/policy-$policy_id.json"
  done <<< "$policies"
done
