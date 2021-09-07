#!/bin/bash


source scripts/common.sh
deployment="Tyk"

log_start_deployment
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
portal_base_url="http://tyk-portal.localhost:3000"
portal_organisation_2_base_url="http://acme-portal.localhost:3000"
gateway_base_url="http://tyk-gateway.localhost:8080"
gateway_base_url_tcp="tyk-gateway.localhost:8086"
gateway2_base_url="https://tyk-gateway-2.localhost:8081"
gateway_image_tag=$(docker ps --filter "name=tyk-demo_tyk-gateway_1" --format "{{.Image}}" | awk -F':' '{print $2}')
gateway2_image_tag=$(docker ps --filter "name=tyk-demo_tyk-gateway-2_1" --format "{{.Image}}" | awk -F':' '{print $2}')
dashboard_image_tag=$(docker ps --filter "name=tyk-demo_tyk-dashboard_1" --format "{{.Image}}" | awk -F':' '{print $2}')

log_message "Checking Dashboard licence exists"
if ! grep -q "DASHBOARD_LICENCE=" .env
then
  echo "ERROR: Dashboard licence missing from Docker environment file. Add a licence to the DASHBOARD_LICENCE variable in the .env file."
  exit 1
fi
log_ok
bootstrap_progress

log_message "Checking Dashboard licence expiry"
licence_days_remaining=0
check_licence_expiry "DASHBOARD_LICENCE"
if [[ "$?" -eq "1" ]]; then
  echo "ERROR: Tyk Dashboard licence has expired. Update DASHBOARD_LICENCE variable in .env file with a new licence."
  exit 1
fi
dashboard_licence_days_remaining=$licence_days_remaining
bootstrap_progress

log_message "Getting Dashboard configuration"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>> bootstrap.log)
log_message "  Dashboard Admin API Credentials = $dashboard_admin_api_credentials"
portal_root_path=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .host_config.portal_root_path 2>> bootstrap.log)
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
gateway2_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk-2.conf | jq -r .secret)
bootstrap_progress

log_message "Waiting for Dashboard API to be ready"
wait_for_response "$dashboard_base_url/admin/organisations" "200" "admin-auth: $dashboard_admin_api_credentials"

# Python plugin

log_message "Building Python plugin bundle"
docker exec tyk-demo_tyk-gateway_1 sh -c "cd /opt/tyk-gateway/middleware/python/basic-example; /opt/tyk-gateway/tyk bundle build -k /opt/tyk-gateway/certs/private-key.pem" 1>> /dev/null 2>> bootstrap.log
log_ok
bootstrap_progress

log_message "Copying Python bundle to http-server"
docker cp tyk-demo_tyk-gateway_1:/opt/tyk-gateway/middleware/python/basic-example/bundle.zip deployments/tyk/volumes/http-server/python-basic-example.zip
log_ok
bootstrap_progress

log_message "Removing Python bundle intermediate assets"
rm -r deployments/tyk/volumes/tyk-gateway/middleware/python/basic-example/bundle.zip
log_ok
bootstrap_progress

# Go plugins

# build_go_plugin "example-go-plugin.so" "example"
# bootstrap_progress

# build_go_plugin "jwt-go-plugin.so" "jwt"
# bootstrap_progress

# Organisations
log_message "Creating Organisations"
organisation_ids=()
organisation_names=()

for file in deployments/tyk/data/tyk-dashboard/organisations/*; do
  if [[ -f $file ]]; then
    create_organisation "$file"
    if [[ "$?" == "1" ]]; then
      echo "ERROR: Failed to create Organisation"
      exit 1;
    fi
    bootstrap_progress
  fi
done

# Dashboard Users
log_message "Creating Dashboard Users"
dashboard_user_emails=()
dashboard_user_passwords=()
dashboard_user_api_keys=()

for file in deployments/tyk/data/tyk-dashboard/users/*; do
  if [[ -f $file ]]; then
    create_dashboard_user "$file"
    if [[ "$?" == "1" ]]; then
      echo "ERROR: Failed to create Dashboard User"
      exit 1;
    fi
    bootstrap_progress
  fi
done

# User Groups
log_message "Creating Dashboard User Groups"
dashboard_user_group_ids=()

for file in deployments/tyk/data/tyk-dashboard/user-groups/*; do
  if [[ -f $file ]]; then
    echo "APIKEY: ${dashboard_user_api_keys[0]}"
    create_user_group "$file" "${dashboard_user_api_keys[0]}"
    if [[ "$?" == "1" ]]; then
      echo "ERROR: Failed to create Dashboard User Group"
      exit 1;
    fi
    bootstrap_progress
  fi
done


# result=$(curl $dashboard_base_url/api/usergroups -s \
#   -H "Authorization: $dashboard_user_api_credentials" \
#   -d @deployments/tyk/data/tyk-dashboard/usergroup-readonly.json 2>> bootstrap.log | jq -r '.Status')
# log_message "  Read-only group:$result"
# result=$(curl $dashboard_base_url/api/usergroups -s \
#   -H "Authorization: $dashboard_user_api_credentials" \
#   -d @deployments/tyk/data/tyk-dashboard/usergroup-default.json 2>> bootstrap.log | jq -r '.Status')
# log_message "  Default group:$result"
# result=$(curl $dashboard_base_url/api/usergroups -s \
#   -H "Authorization: $dashboard_user_api_credentials" \
#   -d @deployments/tyk/data/tyk-dashboard/usergroup-admin.json 2>> bootstrap.log | jq -r '.Status')
# log_message "  Admin group:$result"
# user_group_data=$(curl $dashboard_base_url/api/usergroups -s \
#   -H "Authorization: $dashboard_user_api_credentials" 2>> bootstrap.log)
# echo $user_group_data | jq -r .groups[0].id > .context-data/user-group-readonly-id
# echo $user_group_data | jq -r .groups[1].id > .context-data/user-group-default-id
# echo $user_group_data | jq -r .groups[2].id > .context-data/user-group-admin-id
# bootstrap_progress

# Webhooks

log_message "Creating webhooks"
log_json_result "$(curl $dashboard_base_url/api/hooks -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/webhook-webhook-receiver-api-post.json 2>> bootstrap.log)"
bootstrap_progress

# Portals

log_message "Creating Portal for organisation $organisation_name"

log_message "  Creating Portal default settings"
log_json_result "$(curl $dashboard_base_url/api/portal/configuration -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d "{}" 2>> bootstrap.log)"
bootstrap_progress

log_message "  Initialising Catalogue"
result=$(curl $dashboard_base_url/api/portal/catalogue -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d '{"org_id": "'$organisation_id'"}' 2>> bootstrap.log)
catalogue_id=$(echo "$result" | jq -r '.Message')
log_json_result "$result"
bootstrap_progress

log_message "  Creating Portal home page"
log_json_result "$(curl $dashboard_base_url/api/portal/pages -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/portal-home-page.json 2>> bootstrap.log)"
bootstrap_progress

log_message "  Creating Portal user"
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

log_message "  Creating documentation"
policies=$(curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" 2>> bootstrap.log)
echo -n '{
          "api_id":"",
          "doc_type":"swagger",
          "documentation":"' >/tmp/swagger_encoded.out
cat deployments/tyk/data/tyk-dashboard/documentation-swagger-petstore.json | base64 >>/tmp/swagger_encoded.out
echo '"}' >>/tmp/swagger_encoded.out
result=$(curl $dashboard_base_url/api/portal/documentation -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d "@/tmp/swagger_encoded.out" \
     2>> bootstrap.log)
documentation_swagger_petstore_id=$(echo "$result" | jq -r '.Message')
log_json_result "$result"
rm /tmp/swagger_encoded.out
bootstrap_progress

log_message "  Updating catalogue"
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

log_message "Creating Portal for organisation $organisation_2_name"

log_message "  Creating Portal default settings"
log_json_result "$(curl $dashboard_base_url/api/portal/configuration -s \
  -H "Authorization: $dashboard_user_organisation_2_api_credentials" \
  -d "{}" 2>> bootstrap.log)"
bootstrap_progress

log_message "  Initialising Catalogue"
result=$(curl $dashboard_base_url/api/portal/catalogue -s \
  -H "Authorization: $dashboard_user_organisation_2_api_credentials" \
  -d '{"org_id": "'$organisation_2_id'"}' 2>> bootstrap.log)
catalogue_id=$(echo "$result" | jq -r '.Message')
log_json_result "$result"
bootstrap_progress

log_message "  Creating Portal home page"
log_json_result "$(curl $dashboard_base_url/api/portal/pages -s \
  -H "Authorization: $dashboard_user_organisation_2_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/portal-home-page.json 2>> bootstrap.log)"
bootstrap_progress

log_message "  Creating Portal user"
portal_user_email=$(jq -r '.email' deployments/tyk/data/tyk-dashboard/portal-user.json)
portal_user_password=$(jq -r '.password' deployments/tyk/data/tyk-dashboard/portal-user.json)
log_json_result "$(curl $dashboard_base_url/api/portal/developers -s \
  -H "Authorization: $dashboard_user_organisation_2_api_credentials" \
  -d '{
      "email": "'$portal_user_email'",
      "password": "'$portal_user_password'",
      "org_id": "'$organisation_2_id'"
    }' 2>> bootstrap.log)"
bootstrap_progress

# APIs & Policies

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

log_message "Importing APIs for organisation: $organisation_name"
echo $api_data >/tmp/api_data.out
log_json_result "$(curl $dashboard_base_url/admin/apis/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "@/tmp/api_data.out")"
rm /tmp/api_data.out
bootstrap_progress

log_message "Importing APIs for organisation: $organisation_2_name"
log_json_result "$(curl $dashboard_base_url/admin/apis/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "@deployments/tyk/data/tyk-dashboard/apis-organisation-2.json")"
bootstrap_progress

log_message "Importing Policies for organisation: $organisation_name"
echo $policy_data >/tmp/policy_data.out
log_json_result "$(curl $dashboard_base_url/admin/policies/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "@/tmp/policy_data.out")"
rm /tmp/policy_data.out
bootstrap_progress

log_message "Importing Policies for organisation: $organisation_2_name"
log_json_result "$(curl $dashboard_base_url/admin/policies/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d "@deployments/tyk/data/tyk-dashboard/policies-organisation-2.json")"
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
# Policies need to be 'refreshed' using the original policies.json data as the admin import endpoint does not correctly import all the data from the v3 policy schema
policies_data=$(cat deployments/tyk/data/tyk-dashboard/policies.json)
echo $policies_data | jq --raw-output '.Data[]._id' | while read policy_id
do
  policy_data=$(echo $policies_data | jq --arg pol_id "$policy_id" '.Data[] | select( ._id == $pol_id )')
  policy_name=$(echo $policy_data | jq -r '.name')
  policy_graphql_update_data=$(jq --arg pol_id "$policy_id" --argjson pol_data "$policy_data" '.variables.id = $pol_id | .variables.input = $pol_data' deployments/tyk/data/tyk-dashboard/update-policy-graphql-template.json)
  echo $policy_graphql_update_data >/tmp/policy_graphql_update_data.out  
  result=$(curl $dashboard_base_url/graphql -s \
    -H "Authorization: $dashboard_user_api_credentials" \
    -d "@/tmp/policy_graphql_update_data.out" | jq -r '.data.update_policy.status')
  log_message "  $policy_name:$result"
  rm /tmp/policy_graphql_update_data.out  
done
bootstrap_progress

# System

log_message "Reloading Gateways"
hot_reload "$gateway_base_url" "$gateway_api_credentials" "group"
bootstrap_progress

log_message "Checking Gateway - Basic API access"
result=""
while [ "$result" != "0" ]
do
  wait_for_response "$gateway_base_url/basic-open-api/get" "200" "" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    log_message "  Gateway not returning desired response, attempting hot reload"
    hot_reload "$gateway_base_url" "$gateway_api_credentials"
    sleep 2
  fi
done
bootstrap_progress

log_message "Checking Gateway - Python middleware"
result=""
while [ "$result" != "0" ]
do
  wait_for_response "$gateway_base_url/python-middleware-api/get" "200" "" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    log_message "  Gateway not returning desired response, attempting hot reload"
    hot_reload "$gateway_base_url" "$gateway_api_credentials"
    sleep 2
  fi
done
bootstrap_progress

log_message "Checking Gateway - Go plugin"
result=""
while [ "$result" != "0" ]
do
  wait_for_response "$gateway_base_url/go-plugin-api-no-auth/get" "200" "" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    log_message "  Gateway not returning desired response, attempting hot reload"
    hot_reload "$gateway_base_url" "$gateway_api_credentials"
    sleep 2
  fi
done
bootstrap_progress

log_message "Checking Gateway 2 - Basic API access"
result=""
while [ "$result" != "0" ]
do
  wait_for_response "$gateway2_base_url/basic-open-api/get" "200" "" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    log_message "  Gateway 2 not returning desired response, attempting hot reload"
    hot_reload "$gateway2_base_url" "$gateway2_api_credentials" 
    sleep 2
  fi
done
bootstrap_progress

log_message "Importing custom keys"
result=$(curl $gateway_base_url/tyk/keys/auth_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @deployments/tyk/data/tyk-gateway/auth-key.json 2>> bootstrap.log | jq -r '.status')
log_message "  Auth key:$result"
result=$(curl $gateway_base_url/tyk/keys/auth_key_analytics_on -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @deployments/tyk/data/tyk-gateway/auth-key-analytics-on.json 2>> bootstrap.log | jq -r '.status')
log_message "  Auth key (analytics on):$result"
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
result=$(curl $gateway_base_url/tyk/keys/go_plugin_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @deployments/tyk/data/tyk-gateway/go-plugin-key.json 2>> bootstrap.log | jq -r '.status')
log_message "  Go Plugin key:$result"
result=$(curl $dashboard_base_url/api/apis/keys/basic/basic-auth-username -s -w "%{http_code}" -o /dev/null \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/key-basic-auth.json 2>> bootstrap.log)
log_message "  Basic auth key:$result"
bootstrap_progress

log_message "Sending API requests to generate analytics data"
# global analytics off
curl $gateway_base_url/basic-open-api/get -s -o /dev/null 
# global analytics on
curl $gateway2_base_url/basic-open-api/get -s -k -o /dev/null
# api analytics off
curl $gateway_base_url/detailed-analytics-off/get -s -o /dev/null
# api analytics on
curl $gateway_base_url/detailed-analytics-on/get -s -o /dev/null 
# key analytics off
curl $gateway_base_url/basic-protected-api/ -s -H "Authorization: auth_key" -o /dev/null 
# key analytics on
curl $gateway_base_url/basic-protected-api/ -s -H "Authorization: auth_key_analytics_on" -o /dev/null 
# enforce timeout plugin
curl $gateway_base_url/plugin-demo-api/delay/6 -s -o /dev/null 
log_ok

log_message "Restarting Dashboard container to ensure Portal URLs are loaded ok"
docker restart tyk-demo_tyk-dashboard_1
log_ok
bootstrap_progress

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
  ▽ Dashboard ($dashboard_image_tag)
                Licence : $dashboard_licence_days_remaining days remaining
                    URL : $dashboard_base_url
       API AuthZ Header : Authorization
    ▾ $organisation_name Organisation
               Username : $dashboard_user_email
               Password : $dashboard_user_password
        API Credentials : $dashboard_user_api_credentials
    ▾ $organisation_2_name Organisation
               Username : $dashboard_user_organisation_2_email
               Password : $dashboard_user_organisation_2_password
        API Credentials : $dashboard_user_organisation_2_api_credentials
    ▾ Multi-Organisation User
               Username : $dashboard_multi_organisation_user_email
               Password : $dashboard_multi_organisation_user_password
  ▽ Portal ($dashboard_image_tag)
    ▾ $organisation_name Organisation
                    URL : $portal_base_url$portal_root_path
               Username : $portal_user_email
               Password : $portal_user_password  
    ▾ $organisation_2_name Organisation
                    URL : $portal_organisation_2_base_url$portal_root_path
               Username : $portal_user_email
               Password : $portal_user_password  
  ▽ Gateway ($gateway_image_tag)
                    URL : $gateway_base_url
               URL(TCP) : $gateway_base_url_tcp
        API Credentials : $gateway_api_credentials
       API AuthZ Header : x-tyk-authorization
  ▽ Gateway 2 ($gateway2_image_tag)
                    URL : $gateway2_base_url  
        API Credentials : $gateway2_api_credentials
       API AuthZ Header : x-tyk-authorization"
