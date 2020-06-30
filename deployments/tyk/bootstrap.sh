#!/bin/bash

source scripts/common.sh
deployment="Tyk"

log_start_deployment
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
portal_base_url="http://tyk-portal.localhost:3000"
gateway_base_url="http://tyk-gateway.localhost:8080"
gateway2_base_url="https://tyk-gateway-2.localhost:8081"

log_message "Getting Dashboard configuration"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>> bootstrap.log)
log_message "  Dashboard Admin API Credentials = $dashboard_admin_api_credentials"
portal_root_path=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .host_config.portal_root_path 2>> bootstrap.log)
bootstrap_progress

log_message "Waiting for Dashboard API to be ready"
wait_for_response "$dashboard_base_url/admin/organisations" "200" "admin-auth: $dashboard_admin_api_credentials"

log_message "Importing organisation"
organisation_id=$(curl $dashboard_base_url/admin/organisations/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/organisation.json 2>> bootstrap.log\
  | jq -r '.Meta')
echo $organisation_id > .context-data/organisation-id
log_message "  Org Id = $organisation_id"
bootstrap_progress

log_message "Creating Dashboard user"
dashboard_user_email=$(jq -r '.email_address' deployments/tyk/data/tyk-dashboard/dashboard-user.json)
dashboard_user_password=$(jq -r '.password' deployments/tyk/data/tyk-dashboard/dashboard-user.json)
dashboard_user_api_response=$(curl $dashboard_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/dashboard-user.json 2>> bootstrap.log \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard_user_id=$(echo $dashboard_user_api_response | jq -r '.id')
dashboard_user_api_credentials=$(echo $dashboard_user_api_response | jq -r '.api_key')
curl $dashboard_base_url/api/users/$dashboard_user_id/actions/reset -s -o /dev/null \
  -H "authorization: $dashboard_user_api_credentials" \
  --data-raw '{
      "new_password":"'$dashboard_user_password'",
      "user_permissions": { "IsAdmin": "admin" }
    }' 2>> bootstrap.log
echo "$dashboard_user_api_credentials" > .context-data/dashboard-user-api-credentials
log_message "  Dashboard User API Credentials = $dashboard_user_api_credentials"
bootstrap_progress

log_message "Creating Dashboard user groups"
result=$(curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/usergroup-readonly.json 2>> bootstrap.log | jq -r '.Status')
log_message "  Read-only group:$result"
result=$(curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/usergroup-default.json 2>> bootstrap.log | jq -r '.Status')
log_message "  Default group:$result"
result=$(curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/usergroup-admin.json 2>> bootstrap.log | jq -r '.Status')
log_message "  Admin group:$result"
user_group_data=$(curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" 2>> bootstrap.log)
echo $user_group_data | jq -r .groups[0].id > .context-data/user-group-readonly-id
echo $user_group_data | jq -r .groups[1].id > .context-data/user-group-default-id
echo $user_group_data | jq -r .groups[2].id > .context-data/user-group-admin-id
bootstrap_progress

log_message "Creating webhooks"
log_json_result "$(curl $dashboard_base_url/api/hooks -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/webhook-webhook-receiver-api-post.json 2>> bootstrap.log)"
bootstrap_progress

log_message "Creating Portal default settings"
log_json_result "$(curl $dashboard_base_url/api/portal/configuration -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d "{}" 2>> bootstrap.log)"
bootstrap_progress

log_message "Initialising Catalogue"
result=$(curl $dashboard_base_url/api/portal/catalogue -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d '{"org_id": "'$organisation_id'"}' 2>> bootstrap.log)
catalogue_id=$(echo "$result" | jq -r '.Message')
log_json_result "$result"
bootstrap_progress

log_message "Creating Portal home page"
log_json_result "$(curl $dashboard_base_url/api/portal/pages -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/portal-home-page.json 2>> bootstrap.log)"
bootstrap_progress

log_message "Creating Portal user"
portal_user_email=$(jq -r '.email' deployments/tyk/data/tyk-dashboard/portal-user.json)
portal_user_password=$(jq -r '.password' deployments/tyk/data/tyk-dashboard/portal-user.json)
log_json_result "$(curl $dashboard_base_url/api/portal/developers -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d '{
      "email": "'$portal_user_email'",
      "password": "'$portal_user_password'",
      "org_id": "'$organisation_id'"
    }' 2>> bootstrap.log)"
bootstrap_progress

log_message "Creating documentation"
policies=$(curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" 2>> bootstrap.log)
result=$(curl $dashboard_base_url/api/portal/documentation -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  --data-raw '{
      "api_id":"",
      "doc_type":"swagger",
      "documentation":"'$(cat deployments/tyk/data/tyk-dashboard/documentation-swagger-petstore.json | base64)'"
    }' 2>> bootstrap.log)
documentation_swagger_petstore_id=$(echo "$result" | jq -r '.Message')
log_json_result "$result"
bootstrap_progress

log_message "Updating catalogue"
policy_data=$(cat deployments/tyk/data/tyk-dashboard/policies.json)
policies_swagger_petstore_id=$(echo $policy_data | jq -r '.Data[] | select(.name=="Swagger Petstore Policy") | .id')
catalogue_data=$(cat deployments/tyk/data/tyk-dashboard/catalogue.json | \
  sed 's/CATALOGUE_ID/'"$catalogue_id"'/' | \
  sed 's/ORGANISATION_ID/'"$organisation_id"'/' | \
  sed 's/CATALOGUE_SWAGGER_PETSTORE_POLICY_ID/'"$policies_swagger_petstore_id"'/' | \
  sed 's/CATALOGUE_SWAGGER_PETSTORE_DOCUMENTATION_ID/'"$documentation_swagger_petstore_id"'/')
log_json_result "$(curl $dashboard_base_url/api/portal/catalogue -X 'PUT' -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d "$(echo $catalogue_data)" 2>> bootstrap.log)"
bootstrap_progress

# Broken references occur because the ID of the data changes when it is created
# This means the references to this data must be 'reconnected' to the new IDs
# This is done before the APIs are imported, and after all the other data is imported, so we know the new IDs and can update the API data before importing it
log_message "Updating IDs"
api_data=$(cat deployments/tyk/data/tyk-dashboard/apis.json)
webhook_data=$(curl $dashboard_base_url/api/hooks?p=-1 -s \
  -H "Authorization: $dashboard_user_api_credentials" | \
  jq '.hooks[]')
# only process webhooks if any exist
if [ "$webhook_data" != "" ]
then
  log_message "  Webhooks"
  for webhook_id in $(echo $webhook_data | jq --raw-output '.id')
  do
    # Match old data using the webhook name, which is consistent
    webhook_name=$(echo "$webhook_data" | jq -r --arg webhook_id "$webhook_id" 'select ( .id == $webhook_id ) .name')
    log_message "    $webhook_name"
    # Hook references
    api_data=$(echo $api_data | jq --arg webhook_id "$webhook_id" --arg webhook_name "$webhook_name" '(.apis[].hook_references[] | select(.hook.name == $webhook_name) .hook.id) = $webhook_id')
    # AuthFailure event handlers
    api_data=$(echo $api_data | jq --arg webhook_id "$webhook_id" --arg webhook_name "$webhook_name" '(.apis[].api_definition.event_handlers.events.AuthFailure[]? | select(.handler_meta.name == $webhook_name) .handler_meta.id) = $webhook_id')
  done
fi
bootstrap_progress

log_message "Importing APIs"
log_json_result "$(curl $dashboard_base_url/admin/apis/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$api_data")"
bootstrap_progress

log_message "Importing Policies"
log_json_result "$(curl $dashboard_base_url/admin/policies/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "$policy_data")"
bootstrap_progress

log_message "Refreshing APIs"
# This helps correct some strange behaviour observed with imported data
cat deployments/tyk/data/tyk-dashboard/apis.json | jq --raw-output '.apis[].api_definition.id' | while read api_id
do
  # Get the API definition from the Dashboard
  api_definition=$(curl $dashboard_base_url/api/apis/$api_id -s \
    -H "Authorization: $dashboard_user_api_credentials")
  # Put the API definition into the Dashboard
  result=$(curl $dashboard_base_url/api/apis/$api_id -X PUT -s \
    -H "Authorization: $dashboard_user_api_credentials" \
    --data "$api_definition" | jq -r '.Status')
  log_message "  $(echo $api_definition | jq -r '.api_definition.name'):$result"
done
bootstrap_progress

log_message "Refreshing Policies"
# This is done for good measure, as per API Definitions, even though it's probably not needed for Policies
cat deployments/tyk/data/tyk-dashboard/policies.json | jq --raw-output '.Data[]._id' | while read policy_id
do
  policy_definition=$(curl $dashboard_base_url/api/portal/policies/$policy_id -s \
    -H "Authorization: $dashboard_user_api_credentials")
  result=$(curl $dashboard_base_url/api/portal/policies/$policy_id -X PUT -s \
    -H "Authorization: $dashboard_user_api_credentials" \
    --data "$policy_definition" | jq -r '.Status')
  log_message "  $(echo $policy_definition | jq -r '.name'):$result"
done
bootstrap_progress

log_message "Waiting for Gateway API to be ready"
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
log_message "  Gateway API credentials = $gateway_api_credentials"
gateway_status=""
while [ "$gateway_status" != "200" ]
do
  gateway_status=$(curl $gateway_base_url/tyk/keys/api_key_write_test -s -o /dev/null -w "%{http_code}" -H "x-tyk-authorization: $gateway_api_credentials" -d @deployments/tyk/data/tyk-gateway/auth-key.json 2>> bootstrap.log)

  if [ "$gateway_status" != "200" ]
  then
    # if we get a 403 then there's an issue with authentication
    if [ "$gateway_status" == "403" ]
    then
      log_message "  ERROR: Gateway returned 403 status when using key $gateway_api_credentials"
      break
    fi
    # if we get a 500 then it's probably because the Gateway hasn't received the reload signal from when the Dashboard data was imported, so force reload now
    if [ "$gateway_status" == "500" ]
    then
      log_message "  Reloading Gateway due to HTTP 500 response"
      curl $gateway_base_url/tyk/reload -s -o /dev/null -H "x-tyk-authorization: $gateway_api_credentials" 2>> bootstrap.log
      sleep 2
    else
      log_message "  Request unsuccessful, retrying..."
    fi
    sleep 2
  else
    log_ok
  fi
  bootstrap_progress
done

log_message "Importing custom keys"
result=$(curl $gateway_base_url/tyk/keys/auth_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @deployments/tyk/data/tyk-gateway/auth-key.json 2>> bootstrap.log | jq -r '.status')
log_message "  Auth key:$result"
result=$(curl $gateway_base_url/tyk/keys/ratelimit_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @deployments/tyk/data/tyk-gateway/rate-limit-key.json 2>> bootstrap.log | jq -r '.status')
log_message "  Rate limit key:$result"
result=$(curl $gateway_base_url/tyk/keys/throttle_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @deployments/tyk/data/tyk-gateway/throttle-key.json 2>> bootstrap.log | jq -r '.status')
log_message "  Throttle key:$result"
result=$(curl $gateway_base_url/tyk/keys/quota_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @deployments/tyk/data/tyk-gateway/quota-key.json 2>> bootstrap.log | jq -r '.status')
log_message "  Quota key:$result"
result=$(curl $dashboard_base_url/api/apis/keys/basic/basic-auth-username -s -w "%{http_code}" -o /dev/null \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/key-basic-auth.json 2>> bootstrap.log)
log_message "  Basic auth key:$result"
bootstrap_progress

log_message "Reloading Gateway group to ensure latest configuration is loaded"
sleep 2
result=$(curl $gateway_base_url/tyk/reload/group -s \
  -H "x-tyk-authorization: $gateway_api_credentials" | jq -r '.status')
log_message "  $result"

log_message "Checking Gateway functionality"
sleep 2
wait_for_response "$gateway_base_url/basic-open-api/get" "200"

log_message "Checking Gateway 2 functionality"
gateway2_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk-2.conf | jq -r .secret)
wait_for_response "$gateway2_base_url/basic-open-api/get" "200"

log_end_deployment

echo -e "\033[2K

            #####################                  ####               
            #####################                  ####               
                    #####                          ####               
  /////////         #####    ((.            (((    ####          (((  
  ///////////,      #####    ####         #####    ####       /####   
  ////////////      #####    ####         #####    ####      #####    
  ////////////      #####    ####         #####    ##############     
    //////////      #####    ####         #####    ##############     
                    #####    ####         #####    ####      ,####    
                    #####    ##################    ####        ####   
                    #####      ########## #####    ####         ####  
                                         #####                        
                             ################                         
                               ##########/                            

▼ Tyk
  ▽ Dashboard
               URL : $dashboard_base_url
          Username : $dashboard_user_email
          Password : $dashboard_user_password
   API Credentials : $dashboard_user_api_credentials  
  ▽ Portal
               URL : $portal_base_url$portal_root_path
          Username : $portal_user_email
          Password : $portal_user_password  
  ▽ Gateway
               URL : $gateway_base_url
   API Credentials : $gateway_api_credentials
  ▽ Gateway 2
               URL : $gateway2_base_url  
   API Credentials : $gateway2_api_credentials"
