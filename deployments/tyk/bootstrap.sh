#!/bin/bash


source scripts/common.sh
deployment="Tyk"

log_start_deployment
bootstrap_progress

dashboard_base_url="http://tyk-dashboard.localhost:3000"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
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

# NOTE: commented out until go compiler issue is resolved
# build_go_plugin "example-go-plugin.so" "example"
# bootstrap_progress

# build_go_plugin "jwt-go-plugin.so" "jwt"
# bootstrap_progress

# Dashboard Data

log_message "Processing Dashboard Data"
for data_group_path in deployments/tyk/data/tyk-dashboard/*; do
  if [[ -d $data_group_path ]]; then
    log_message "Processing data in $data_group_path"
    data_group="${data_group_path##*/}"

    # Organisation
    log_message "Creating Organisation"
    organisation_data_path="$data_group_path/organisation.json"
    if [[ ! -f $organisation_data_path ]]; then
          log_message "ERROR: organisation file missing: $organisation_data_path"
          exit 1
    fi
    create_organisation "$organisation_data_path" "$dashboard_admin_api_credentials" "$data_group" "1"
    bootstrap_progress
    organisation_id=$(get_context_data "$data_group" "organisation" "1" "id")

    # Dashboard Users
    log_message "Creating Dashboard Users"
    index=1
    for file in $data_group_path/users/*; do
      if [[ -f $file ]]; then
        create_dashboard_user "$file" "$dashboard_admin_api_credentials" "$data_group" "$index"
        index=$((index + 1))
        bootstrap_progress
      fi
    done

    # first user added should be an admin, so that it's key can be used for Dashboard API calls
    dashboard_user_api_key=$(get_context_data "$data_group" "dashboard-user" "1" "api-key")

    # User Groups
    log_message "Creating Dashboard User Groups"
    index=1
    for file in $data_group_path/user-groups/*; do
      if [[ -f $file ]]; then
        create_user_group "$file" "$dashboard_user_api_key" "$data_group" "$index"
        index=$((index + 1))
        bootstrap_progress
      fi
    done

    # Webhooks
    log_message "Creating Webhooks"
    for file in $data_group_path/webhooks/*; do
      if [[ -f $file ]]; then
        create_webhook "$file" "$dashboard_user_api_key"
        bootstrap_progress
      fi
    done

    # APIs
    log_message "Creating APIs"
    for file in $data_group_path/apis/*; do
      if [[ -f $file ]]; then
        create_api "$file" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
        bootstrap_progress
      fi
    done

    # Policies
    log_message "Creating Policies"
    for file in $data_group_path/policies/*; do
      if [[ -f $file ]]; then
        create_policy "$file" "$dashboard_admin_api_credentials" "$dashboard_user_api_key"
        bootstrap_progress
      fi
    done    

    # Portal - Initialise
    log_message "Initialising Portal"
    initialise_portal "$organisation_id" "$dashboard_user_api_key"
    bootstrap_progress
    
    # Portal - Pages
    log_message "Creating Portal Pages"
    for file in $data_group_path/portal/pages/*; do
      if [[ -f $file ]]; then
        create_portal_page "$file" "$dashboard_user_api_key"
        bootstrap_progress        
      fi
    done

    # Portal - Developers
    log_message "Creating Portal Developers"
    index=1
    for file in $data_group_path/portal/developers/*; do
      if [[ -f $file ]]; then
        create_portal_developer "$file" "$dashboard_user_api_key" "$index"
        index=$((index + 1))
        bootstrap_progress        
      fi
    done

    # Portal - Catalogues
    log_message "Creating Portal Catalogues"
    for directory in $data_group_path/portal/catalogues/*; do
      if [[ -d $directory ]]; then
        documentation_path="$directory/documentation.json"
        documentation_id=""
        if [[ -f $documentation_path ]]; then
          documentation_id=$(create_portal_documentation "$documentation_path" "$dashboard_user_api_key")
        fi
        bootstrap_progress        

        catalogue_path="$directory/catalogue.json"
        if [[ -f $catalogue_path ]]; then
          create_portal_catalogue "$catalogue_path" "$dashboard_user_api_key" "$documentation_id"
        else
          log_message "ERROR: catalogue file missing: $catalogue_path"
          exit 1
        fi
        bootstrap_progress        
      fi
    done

    # Keys - Basic
    log_message "Creating Basic Auth Keys"
    for file in $data_group_path/keys/basic/*; do
      if [[ -f $file ]]; then
        create_basic_key "$file" "$dashboard_user_api_key"
        bootstrap_progress        
      fi
    done
  fi
done

# Gateway Data
log_message "Processing Gateway Data"

# Bearer Tokens
log_message "Creating Custom Bearer Tokens"
for file in deployments/tyk/data/tyk-gateway/keys/bearer-token/*; do
  if [[ -f $file ]]; then
    create_bearer_token "$file" "$gateway_api_credentials"
    bootstrap_progress
  fi
done


# APIs & Policies

# # Broken references occur because the ID of the data changes when it is created
# # This means the references to this data must be 'reconnected' to the new IDs
# # This is done before the APIs are imported, and after all the other data is imported, so we know the new IDs and can update the API data before importing it
# log_message "Updating IDs"
# api_data=$(cat deployments/tyk/data/tyk-dashboard/apis.json)
# webhook_data=$(curl $dashboard_base_url/api/hooks?p=-1 -s \
#   -H "Authorization: $dashboard_user_api_credentials" | \
#   jq '.hooks[]')
# # only process webhooks if any exist
# if [ "$webhook_data" != "" ]
# then
#   log_message "  Webhooks"
#   for webhook_id in $(echo $webhook_data | jq --raw-output '.id')
#   do
#     # Match old data using the webhook name, which is consistent
#     webhook_name=$(echo "$webhook_data" | jq -r --arg webhook_id "$webhook_id" 'select ( .id == $webhook_id ) .name')
#     log_message "    $webhook_name"
#     # Hook references
#     api_data=$(echo $api_data | jq --arg webhook_id "$webhook_id" --arg webhook_name "$webhook_name" '(.apis[].hook_references[] | select(.hook.name == $webhook_name) .hook.id) = $webhook_id')
#     # AuthFailure event handlers
#     api_data=$(echo $api_data | jq --arg webhook_id "$webhook_id" --arg webhook_name "$webhook_name" '(.apis[].api_definition.event_handlers.events.AuthFailure[]? | select(.handler_meta.name == $webhook_name) .handler_meta.id) = $webhook_id')
#   done
# fi
# bootstrap_progress

# log_message "Importing APIs for organisation: $organisation_name"
# echo $api_data >/tmp/api_data.out
# log_json_result "$(curl $dashboard_base_url/admin/apis/import -s \
#   -H "admin-auth: $dashboard_admin_api_credentials" \
#   -d "@/tmp/api_data.out")"
# rm /tmp/api_data.out
# bootstrap_progress

# log_message "Importing APIs for organisation: $organisation_2_name"
# log_json_result "$(curl $dashboard_base_url/admin/apis/import -s \
#   -H "admin-auth: $dashboard_admin_api_credentials" \
#   -d "@deployments/tyk/data/tyk-dashboard/apis-organisation-2.json")"
# bootstrap_progress

# log_message "Importing Policies for organisation: $organisation_name"
# echo $policy_data >/tmp/policy_data.out
# log_json_result "$(curl $dashboard_base_url/admin/policies/import -s \
#   -H "admin-auth: $dashboard_admin_api_credentials" \
#   -d "@/tmp/policy_data.out")"
# rm /tmp/policy_data.out
# bootstrap_progress

# log_message "Importing Policies for organisation: $organisation_2_name"
# log_json_result "$(curl $dashboard_base_url/admin/policies/import -s \
#   -H "admin-auth: $dashboard_admin_api_credentials" \
#   -d "@deployments/tyk/data/tyk-dashboard/policies-organisation-2.json")"
# bootstrap_progress

# log_message "Refreshing APIs"
# # This helps correct some strange behaviour observed with imported data
# cat deployments/tyk/data/tyk-dashboard/apis.json | jq --raw-output '.apis[].api_definition.id' | while read api_id
# do
#   # Get the API definition from the Dashboard
#   api_definition=$(curl $dashboard_base_url/api/apis/$api_id -s \
#     -H "Authorization: $dashboard_user_api_credentials")
#   # Put the API definition into the Dashboard
#   result=$(curl $dashboard_base_url/api/apis/$api_id -X PUT -s \
#     -H "Authorization: $dashboard_user_api_credentials" \
#     --data "$api_definition" | jq -r '.Status')
#   log_message "  $(echo $api_definition | jq -r '.api_definition.name'):$result"
# done
# bootstrap_progress

# log_message "Refreshing Policies"
# # Policies need to be 'refreshed' using the original policies.json data as the admin import endpoint does not correctly import all the data from the v3 policy schema
# policies_data=$(cat deployments/tyk/data/tyk-dashboard/policies.json)
# echo $policies_data | jq --raw-output '.Data[]._id' | while read policy_id
# do
#   policy_data=$(echo $policies_data | jq --arg pol_id "$policy_id" '.Data[] | select( ._id == $pol_id )')
#   policy_name=$(echo $policy_data | jq -r '.name')
#   policy_graphql_update_data=$(jq --arg pol_id "$policy_id" --argjson pol_data "$policy_data" '.variables.id = $pol_id | .variables.input = $pol_data' deployments/tyk/data/tyk-dashboard/update-policy-graphql-template.json)
#   echo $policy_graphql_update_data >/tmp/policy_graphql_update_data.out  
#   result=$(curl $dashboard_base_url/graphql -s \
#     -H "Authorization: $dashboard_user_api_credentials" \
#     -d "@/tmp/policy_graphql_update_data.out" | jq -r '.data.update_policy.status')
#   log_message "  $policy_name:$result"
#   rm /tmp/policy_graphql_update_data.out  
# done
# bootstrap_progress

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
  bootstrap_progress
done
log_ok

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
  bootstrap_progress
done
log_ok

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
  bootstrap_progress
done
log_ok

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
  bootstrap_progress
done
log_ok

log_message "Sending API requests to generate analytics data"
# global analytics off
curl $gateway_base_url/basic-open-api/get -s -o /dev/null 
bootstrap_progress
# global analytics on
curl $gateway2_base_url/basic-open-api/get -s -k -o /dev/null
bootstrap_progress
# api analytics off
curl $gateway_base_url/detailed-analytics-off/get -s -o /dev/null
bootstrap_progress
# api analytics on
curl $gateway_base_url/detailed-analytics-on/get -s -o /dev/null 
bootstrap_progress
# key analytics off
curl $gateway_base_url/basic-protected-api/ -s -H "Authorization: standard_bearer_token" -o /dev/null 
bootstrap_progress
# key analytics on
curl $gateway_base_url/basic-protected-api/ -s -H "Authorization: analytics_on" -o /dev/null 
bootstrap_progress
# enforce timeout plugin
curl $gateway_base_url/plugin-demo-api/delay/6 -s -o /dev/null 
bootstrap_progress
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
       Admin API Header : admin-auth
          Admin API Key : $dashboard_admin_api_credentials 
   Dashboard API Header : Authorization       
    ▾ $(get_context_data "1" "organisation" "1" "name") Organisation
               Username : $(get_context_data "1" "dashboard-user" "1" "email")
               Password : $(get_context_data "1" "dashboard-user" "1" "password")
      Dashboard API Key : $(get_context_data "1" "dashboard-user" "1" "api-key")
    ▾ $(get_context_data "2" "organisation" "1" "name") Organisation
               Username : $(get_context_data "2" "dashboard-user" "1" "email")
               Password : $(get_context_data "2" "dashboard-user" "1" "password")
      Dashboard API Key : $(get_context_data "2" "dashboard-user" "1" "api-key")
    ▾ Multi-Organisation User
               Username : $(get_context_data "1" "dashboard-user" "2" "email")
               Password : $(get_context_data "1" "dashboard-user" "2" "password")
  ▽ Portal ($dashboard_image_tag)
    ▾ $(get_context_data "1" "organisation" "1" "name") Organisation
                    URL : http://$(get_context_data "1" "portal" "1" "hostname")$portal_root_path
               Username : $(get_context_data "1" "portal-developer" "1" "email")
               Password : $(get_context_data "1" "portal-developer" "1" "password")
    ▾ $(get_context_data "2" "organisation" "1" "name") Organisation
                    URL : http://$(get_context_data "2" "portal" "1" "hostname")$portal_root_path
               Username : $(get_context_data "2" "portal-developer" "1" "email")
               Password : $(get_context_data "2" "portal-developer" "1" "password")
  ▽ Gateway ($gateway_image_tag)
                    URL : $gateway_base_url
               URL(TCP) : $gateway_base_url_tcp
     Gateway API Header : x-tyk-authorization
        Gateway API Key : $gateway_api_credentials
  ▽ Gateway 2 ($gateway2_image_tag)
                    URL : $gateway2_base_url  
     Gateway API Header : x-tyk-authorization
        Gateway API Key : $gateway2_api_credentials"
