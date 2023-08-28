#!/bin/bash


source scripts/common.sh
deployment="Tyk"

log_start_deployment
bootstrap_progress

log_message "Setting global variables"
dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url_tcp="tyk-gateway.localhost:8086"
gateway2_base_url="https://tyk-gateway-2.localhost:8081"
log_ok
bootstrap_progress

log_message "Checking Dashboard licence exists"
if ! grep -q "DASHBOARD_LICENCE=" .env; then
  log_message "ERROR: Dashboard licence missing from Docker environment file (.env). Add a licence to the DASHBOARD_LICENCE environment variable."
  exit 1
fi
if grep -q "DASHBOARD_LICENCE=add_your_dashboard_licence_here" .env; then
  log_message "ERROR: Placeholder Dashboard licence found in Docker environment file (.env). Replace \"add_your_dashboard_licence_here\" with your Tyk licence."
  exit 1
fi
log_ok
bootstrap_progress

log_message "Checking Dashboard licence expiry"
licence_days_remaining=0
check_licence_expiry "DASHBOARD_LICENCE"
if [[ "$?" -eq "1" ]]; then
  log_message "ERROR: Tyk Dashboard licence has expired. Update DASHBOARD_LICENCE variable in .env file with a new licence."
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

log_message "Creating new audit log file to prevent uncontrolled growth between deployments"
echo -n > deployments/tyk/volumes/tyk-dashboard/audit/audit.log
log_ok
bootstrap_progress

# Certificates

log_message "OpenSSL version used for generating certs: $(docker exec $(get_service_container_id tyk-gateway) sh -c "openssl version")"

log_message "Generating self-signed certificate for TLS connections to tyk-gateway-2.localhost"
docker exec -d $(get_service_container_id tyk-gateway) sh -c "openssl req -x509 -newkey rsa:4096 -subj \"/CN=tyk-gateway-2.localhost\" -keyout certs/tls-private-key.pem -out certs/tls-certificate.pem -days 365 -nodes" >/dev/null 2>>bootstrap.log
if [ "$?" != "0" ]; then
  echo "ERROR: Could not generate self-signed certificate"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Generating private key for secure messaging and signing"
docker exec -d $(get_service_container_id tyk-gateway) sh -c "openssl genrsa -out certs/private-key.pem 2048" >/dev/null 2>>bootstrap.log
if [ "$?" != "0" ]; then
  echo "ERROR: Could not generate private key"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Copying private key to the Dashboard"
docker cp $(get_service_container_id tyk-gateway):/opt/tyk-gateway/certs/private-key.pem deployments/tyk/volumes/tyk-dashboard/certs 2>>bootstrap.log
if [ "$?" != "0" ]; then
  echo "ERROR: Could not copy private key"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Generating public key for secure messaging and signing"
docker exec -d $(get_service_container_id tyk-gateway) sh -c "openssl rsa -in certs/private-key.pem -pubout -out certs/public-key.pem" >/dev/null 2>>bootstrap.log
if [ "$?" != "0" ]; then
  echo "ERROR: Could not generate public key"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Recreating containers to ensure new certificates are loaded (tyk-gateway, tyk-gateway-2, tyk-dashboard)"
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate tyk-gateway tyk-gateway-2 tyk-dashboard
# if there are gateways from other deployments connecting to this deployment 
# (such as MDCB), then they must be recreated to. The MDCB deployment already 
# handles recreation.
if [ "$?" != "0" ]; then
  echo "ERROR: Could not recreate containers"
  exit 1
fi
log_ok
bootstrap_progress

# Wait for Dashboard API

log_message "Waiting for Dashboard API to be ready"
wait_for_response "$dashboard_base_url/admin/organisations" "200" "admin-auth: $dashboard_admin_api_credentials"

# Python plugin

log_message "Building Python plugin bundle"
docker exec -d $(get_service_container_id tyk-gateway) sh -c "cd /opt/tyk-gateway/middleware/python/basic-example; /opt/tyk-gateway/tyk bundle build -k /opt/tyk-gateway/certs/private-key.pem" 1> /dev/null 2>> bootstrap.log
if [ "$?" != 0 ]; then
  echo "Error occurred when building Python plugin bundle"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Copying Python bundle to http-server"
# we don't use a 'docker compose' command here as docker compose version 1 does not support 'cp'
docker cp $(get_service_container_id tyk-gateway):/opt/tyk-gateway/middleware/python/basic-example/bundle.zip deployments/tyk/volumes/http-server/python-basic-example.zip 2>>bootstrap.log
if [ "$?" != 0 ]; then
  echo "Error occurred when copying Python bundle to http-server"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Removing Python bundle intermediate assets"
rm -r deployments/tyk/volumes/tyk-gateway/middleware/python/basic-example/bundle.zip
if [ "$?" != 0 ]; then
  echo "Error occurred when removing Python bundle intermediate assets"
  exit 1
fi
log_ok
bootstrap_progress

# Go plugins

build_go_plugin "example-go-plugin.so" "example"
bootstrap_progress

build_go_plugin "jwt-go-plugin.so" "jwt"
bootstrap_progress

build_go_plugin "ip-rate-limit.so" "ipratelimit"
bootstrap_progress

log_message "Liveness Health Check"
wait_for_liveness

# Dashboard Data

# The order these are processed in is important, due to dependencies between objects
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
    admin_user_index=-1
    for file in $data_group_path/users/*; do
      if [[ -f $file ]]; then
        create_dashboard_user "$file" "$dashboard_admin_api_credentials" "$data_group" "$index"
        is_admin="$(jq -r '.user_permissions.IsAdmin' $file)"
        if [[ "$is_admin" == "admin" ]]; then
          admin_user_index=$index
        fi
        index=$((index + 1))
        bootstrap_progress
      fi

      if [ "$admin_user_index" -eq "-1" ]; then
        log_message "ERROR: No Dashboard admin user found in data group $data_group_path"
        exit 1
      fi
    done
    log_message "  Dashboard admin user index: $admin_user_index"

    # get admin user dashboard API key for Dashboard API calls
    dashboard_user_api_key=$(get_context_data "$data_group" "dashboard-user" "$admin_user_index" "api-key")

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

        # Swagger Petstore REST
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

        # Social Media REST
        documentation_path="$directory/documentation_socialmedia_rest.json"
        documentation_id=""
        if [[ -f $documentation_path ]]; then
          documentation_id=$(create_portal_documentation "$documentation_path" "$dashboard_user_api_key")
        fi
        bootstrap_progress

        catalogue_path="$directory/catalogue_socialmedia_rest.json"
        if [[ -f $catalogue_path ]]; then
          create_portal_catalogue "$catalogue_path" "$dashboard_user_api_key" "$documentation_id"
        else
          log_message "ERROR: catalogue file missing: $catalogue_path"
          exit 1
        fi

        # Social Media GQL
        documentation_id_graph=$(create_portal_graphql_documentation "$dashboard_user_api_key" "Social Media GQL")
        bootstrap_progress  

        catalogue_path_graph="$directory/catalogue_socialmediagql.json"
        if [[ -f $catalogue_path_graph ]]; then
          create_portal_catalogue "$catalogue_path_graph" "$dashboard_user_api_key" "$documentation_id_graph"
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

    # OAuth - Clients
    log_message "Creating OAuth Clients"
    for file in $data_group_path/oauth/clients/*; do
      if [[ -f $file ]]; then
        create_oauth_client "$file" "$dashboard_user_api_key"
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

# System

log_message "Reloading Gateways"
hot_reload "$gateway_base_url" "$gateway_api_credentials" "group"
bootstrap_progress

log_message "Checking Gateway - Anonymous API access"
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

log_message "Checking Gateway - Authenticated API access (bearer token)"
result=""
while [ "$result" != "0" ]
do
  wait_for_response "$gateway_base_url/basic-protected-api/get" "200" "Authorization:auth_key" 3
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

log_message "Checking Gateway - Authenticated API access (basic)"
result=""
while [ "$result" != "0" ]
do
  wait_for_response "$gateway_base_url/basic-authentication-api/get" "200" "Authorization:Basic YmFzaWNfYXV0aF91c2VybmFtZTpiYXNpYy1hdXRoLXBhc3N3b3Jk" 3
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

log_message "Checking Gateway 2 - Anonymous API access"
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
curl $gateway_base_url/basic-open-api/anything/[1-10] -s -o /dev/null 
bootstrap_progress
# global analytics on
curl $gateway2_base_url/basic-open-api/anything/[1-10] -s -k -o /dev/null
bootstrap_progress
# api analytics off
curl $gateway_base_url/detailed-analytics-off/get -s -o /dev/null
bootstrap_progress
# api analytics on
curl $gateway_base_url/detailed-analytics-on/get -s -o /dev/null 
bootstrap_progress
# key analytics off
curl $gateway_base_url/basic-protected-api/ -s -H "Authorization: auth_key" -o /dev/null 
bootstrap_progress
# key analytics on
curl $gateway_base_url/basic-protected-api/ -s -H "Authorization: analytics_on" -o /dev/null 
bootstrap_progress
log_ok

log_message "Restarting Dashboard container to ensure Portal URLs are loaded ok"
eval $(generate_docker_compose_command) restart tyk-dashboard 1> /dev/null 2>> bootstrap.log
if [ "$?" != 0 ]; then
  echo "Error occurred when restarting Dashboard container"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Getting ngrok public URL for Tyk Gateway"
ngrok_dashboard_url="http://localhost:4040"
ngrok_ip_api_endpoint="$ngrok_dashboard_url/api/tunnels/tyk-gateway"
log_message "  Getting data from $ngrok_ip_api_endpoint"
ngrok_public_url=$(curl --fail --silent --show-error ${ngrok_ip_api_endpoint} | jq ".public_url" --raw-output)
if [ "$?" != 0 ]; then
  echo "Error getting ngrok configuration from $ngrok_ip_api_endpoint"
  exit 1
fi
if [ "$ngrok_public_url" = "" ]; then
  echo "Error: ngrok public URL is empty"
  exit 1
fi
log_message "  Ngrok public URL: $ngrok_public_url"
log_ok

log_end_deployment

NOCOLOUR='\033[0m'
CYAN='\033[0;36m'

echo -e "\033[2K

              ▓▓▓▓▓▓▓▓▓▓▓▓▓          ▓▓▓
                   ▓▓▓               ▓▓▓
        ${CYAN}▓▓▓▓▓${NOCOLOUR}      ▓▓▓  ▓▓▓     ▓▓▓  ▓▓▓     ▓▓
        ${CYAN}▓▓▓▓▓▓▓${NOCOLOUR}    ▓▓▓  ▓▓▓     ▓▓▓  ▓▓▓    ▓▓
          ${CYAN}▓▓▓▓▓${NOCOLOUR}    ▓▓▓  ▓▓▓     ▓▓▓  ▓▓▓▓▓▓▓▓▓
                   ▓▓▓  ▓▓▓     ▓▓▓  ▓▓▓    ▓▓ 
                   ▓▓▓   ▓▓▓▓▓▓▓▓▓▓  ▓▓▓     ▓▓
                                ▓▓▓  
                         ▓▓▓▓▓▓▓▓▓

▼ Tyk
  ▽ Dashboard ($(get_service_image_tag "tyk-dashboard"))
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
  ▽ Portal ($(get_service_image_tag "tyk-dashboard"))
    ▾ $(get_context_data "1" "organisation" "1" "name") Organisation
                    URL : http://$(get_context_data "1" "portal" "1" "hostname")$portal_root_path
               Username : $(get_context_data "1" "portal-developer" "1" "email")
               Password : $(get_context_data "1" "portal-developer" "1" "password")
    ▾ $(get_context_data "2" "organisation" "1" "name") Organisation
                    URL : http://$(get_context_data "2" "portal" "1" "hostname")$portal_root_path
               Username : $(get_context_data "2" "portal-developer" "1" "email")
               Password : $(get_context_data "2" "portal-developer" "1" "password")
  ▽ Gateway ($(get_service_image_tag "tyk-gateway"))
                    URL : $gateway_base_url
               URL(TCP) : $gateway_base_url_tcp
           External URL : $ngrok_public_url
     Gateway API Header : x-tyk-authorization
        Gateway API Key : $gateway_api_credentials
  ▽ Gateway 2 ($(get_service_image_tag "tyk-gateway-2"))
                    URL : $gateway2_base_url  
     Gateway API Header : x-tyk-authorization
        Gateway API Key : $gateway2_api_credentials
  ▽ Ngrok
             Public URL : $ngrok_public_url
          Dashboard URL : $ngrok_dashboard_url"
