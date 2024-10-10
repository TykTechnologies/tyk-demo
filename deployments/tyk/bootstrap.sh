#!/bin/bash


source scripts/common.sh
deployment="Tyk"

log_start_deployment
bootstrap_progress

log_message "Setting global variables"
dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url="http://$(jq -r '.host_config.override_hostname' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
set_context_data "1" "gateway" "1" "base-url" $gateway_base_url
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
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>> logs/bootstrap.log)
log_message "  Dashboard Admin API Credentials = $dashboard_admin_api_credentials"
portal_root_path=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .host_config.portal_root_path 2>> logs/bootstrap.log)
gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
gateway2_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk-2.conf | jq -r .secret)
bootstrap_progress

log_message "Creating new audit log file to prevent uncontrolled growth between deployments"
echo -n > deployments/tyk/volumes/tyk-dashboard/audit/audit.log
log_ok
bootstrap_progress

# Certificates

log_message "Wait for services to be ready before beginning to bootstrap"
wait_for_liveness

log_message "Checking for existing OpenSSL container"
OPENSSL_CONTAINER_NAME="tyk-demo-openssl"
if [ "$(docker ps -a --format '{{.Names}}' | grep -w "$OPENSSL_CONTAINER_NAME" | wc -l)" -gt 0 ]; then
  log_message "Removing existing OpenSSL container $OPENSSL_CONTAINER_NAME"
  docker rm -f $OPENSSL_CONTAINER_NAME > /dev/null
else
  log_ok
fi
bootstrap_progress

log_message "Creating temporary container $OPENSSL_CONTAINER_NAME for OpenSSL usage"
docker run -d --name $OPENSSL_CONTAINER_NAME \
  -v tyk-demo_tyk-gateway-certs:/tyk-gateway-certs \
  -v tyk-demo_tyk-dashboard-certs:/tyk-dashboard-certs \
  alpine:3.20.1 tail -f /dev/null >/dev/null 2>&1
log_ok
bootstrap_progress

log_message "Install OpenSSL into container $OPENSSL_CONTAINER_NAME"
docker exec $OPENSSL_CONTAINER_NAME apk add --no-cache openssl >/dev/null 2>>logs/bootstrap.log
# Wait for the installation to complete
while true; do
    # Check if OpenSSL is installed by trying to get its version
    if docker exec $OPENSSL_CONTAINER_NAME openssl version >/dev/null 2>&1; then
        log_message "  OpenSSL has been successfully installed"
        break
    else
        log_message "  Waiting for OpenSSL to be installed..."
        sleep 2
    fi
done

log_message "OpenSSL version used for generating certs: $(docker exec $OPENSSL_CONTAINER_NAME openssl version)"

log_message "Generating self-signed certificate for TLS connections to tyk-gateway-2.localhost"
docker exec $OPENSSL_CONTAINER_NAME sh -c "openssl req -x509 -newkey rsa:4096 -subj \"/CN=tyk-gateway-2.localhost\" -keyout /tyk-gateway-certs/tls-private-key.pem -out /tyk-gateway-certs/tls-certificate.pem -days 365 -nodes" >/dev/null 2>&1
if [ "$?" -ne "0" ]; then
  echo "ERROR: Could not generate self-signed certificate"
  exit 1
fi
log_ok
bootstrap_progress
wait_for_file "/tyk-gateway-certs/tls-certificate.pem" "$OPENSSL_CONTAINER_NAME"
wait_for_file "/tyk-gateway-certs/tls-private-key.pem" "$OPENSSL_CONTAINER_NAME"

log_message "Generating private key for secure messaging and signing"
docker exec $OPENSSL_CONTAINER_NAME sh -c "openssl genrsa -out /tyk-dashboard-certs/private-key.pem 2048" >/dev/null 2>>logs/bootstrap.log
if [ "$?" -ne "0" ]; then
  echo "ERROR: Could not generate private key"
  exit 1
fi
log_ok
bootstrap_progress
wait_for_file "/tyk-dashboard-certs/private-key.pem" "$OPENSSL_CONTAINER_NAME"

log_message "Generating public key for secure messaging and signing"
docker exec $OPENSSL_CONTAINER_NAME sh -c "openssl rsa -in /tyk-dashboard-certs/private-key.pem -pubout -out /tyk-gateway-certs/public-key.pem" >/dev/null 2>>logs/bootstrap.log
if [ "$?" -ne "0" ]; then
  echo "ERROR: Could not generate public key"
  exit 1
fi
log_ok
bootstrap_progress
wait_for_file "/tyk-gateway-certs/public-key.pem" "$OPENSSL_CONTAINER_NAME"

log_message "Setting read permissions on certificate volumes"
docker exec $OPENSSL_CONTAINER_NAME chmod -R a+r /tyk-gateway-certs >/dev/null 2>>logs/bootstrap.log
if [ "$?" != "0" ]; then
  echo "ERROR: Could not set read permissions on /tyk-gateway-certs volume"
  exit 1
fi
docker exec $OPENSSL_CONTAINER_NAME chmod -R a+r /tyk-dashboard-certs >/dev/null 2>>logs/bootstrap.log
if [ "$?" != "0" ]; then
  echo "ERROR: Could not set read permissions on /tyk-dashboard-certs volume"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Removing temporary OpenSSL container $OPENSSL_CONTAINER_NAME"
docker rm -f $OPENSSL_CONTAINER_NAME >/dev/null 2>>logs/bootstrap.log
if [ "$?" != "0" ]; then
  echo "ERROR: Could not remove temporary OpenSSL container $OPENSSL_CONTAINER_NAME"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Recreating containers to load new certificates"
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate tyk-dashboard
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate tyk-gateway tyk-gateway-2
log_ok

log_message "Wait for services to be available after restart"
wait_for_liveness

# Kafka

log_message "Creating Kafka topics"
kafka_topics=("tyk-streams-example" "jobs")
for kafka_topic_name in "${kafka_topics[@]}"; do
  docker exec tyk-demo-kafka-1 sh -c "/opt/kafka/bin/kafka-topics.sh --create --topic $kafka_topic_name --bootstrap-server localhost:9092" >/dev/null 2>>logs/bootstrap.log
  if [ "$?" -ne "0" ]; then
    echo "ERROR: Could not create kafka topic: $kafka_topic_name"
    exit 1
  fi
  log_message "  Created topic: $kafka_topic_name"
done
log_ok
bootstrap_progress

# Go plugins

build_go_plugin "example-go-plugin.so" "example"
bootstrap_progress

build_go_plugin "jwt-go-plugin.so" "jwt"
bootstrap_progress

build_go_plugin "ip-rate-limit.so" "ipratelimit"
bootstrap_progress

# Dashboard Data

log_message "Wait for services to be ready before importing data"
wait_for_liveness

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

    # Certificates
    log_message "Creating Certificates"
    for file in $data_group_path/certs/*; do
      if [[ -f $file ]]; then
        create_cert "$file" "$dashboard_user_api_key"
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

    log_message "Waiting for API availability"
    # this api id is for the 'basic open api', and will validate that the Gateway has loaded it after it was added to the Dashboard
    wait_for_api_loaded "727dad853a8a45f64ab981154d1ffdad" "$gateway_base_url" "$gateway_api_credentials"
    log_ok
    bootstrap_progress

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

    # Keys - Bearer token
    log_message "Creating Bearer Token Keys"
    for file in $data_group_path/keys/bearer-token/*; do
      if [[ -f $file ]]; then
        create_bearer_token_dash "$file" "$dashboard_user_api_key"
        bootstrap_progress        
      fi
    done

    # OAuth - Clients
    log_message "Creating OAuth Clients"
    for file in $data_group_path/oauth/clients/*; do
      if [[ -f $file ]]; then
        target_api_id=$(cat $file | jq '.api_id' --raw-output)
        # before attempting to create the key we check that the API gateway has loaded the OAuth API, otherwise the request will fail
        wait_for_api_loaded "$target_api_id" "$gateway_base_url" "$gateway_api_credentials"
        # reaching this point means that the gateway has loaded target OAuth API
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
reload_attempt=0
while [ "$result" != "0" ]
do
  wait_for_response "$gateway_base_url/basic-open-api/get" "200" "" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    reload_attempt=$((reload_attempt+1))
    if [ "$reload_attempt" -lt "3"  ]; then
      log_message "  Gateway not returning desired response, attempting hot reload"
      hot_reload "$gateway_base_url" "$gateway_api_credentials"
      sleep 2
    else
      log_message "  Maximum reload attempt reached"
      exit 1
    fi
  fi
  bootstrap_progress
done
log_ok

log_message "Checking Gateway - Authenticated API access (bearer token)"
result=""
reload_attempt=0
while [ "$result" != "0" ]
do
  wait_for_response "$gateway_base_url/basic-protected-api/get" "200" "Authorization:auth_key" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    reload_attempt=$((reload_attempt+1))
    if [ "$reload_attempt" -lt "3"  ]; then
      log_message "  Gateway not returning desired response, attempting hot reload"
      hot_reload "$gateway_base_url" "$gateway_api_credentials"
      sleep 2
    else
      log_message "  Maximum reload attempt reached"
      exit 1
    fi
  fi
  bootstrap_progress
done
log_ok

log_message "Checking Gateway - Authenticated API access (basic)"
result=""
reload_attempt=0
while [ "$result" != "0" ]
do
  wait_for_response "$gateway_base_url/basic-authentication-api/get" "200" "Authorization:Basic YmFzaWNfYXV0aF91c2VybmFtZTpiYXNpYy1hdXRoLXBhc3N3b3Jk" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    reload_attempt=$((reload_attempt+1))
    if [ "$reload_attempt" -lt "3"  ]; then
      log_message "  Gateway not returning desired response, attempting hot reload"
      hot_reload "$gateway_base_url" "$gateway_api_credentials"
      sleep 2
    else
      log_message "  Maximum reload attempt reached"
      exit 1
    fi
  fi
  bootstrap_progress
done
log_ok

log_message "Checking Gateway - Go plugin"
result=""
reload_attempt=0
while [ "$result" != "0" ]
do
  wait_for_response "$gateway_base_url/go-plugin-api-no-auth/get" "200" "" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    reload_attempt=$((reload_attempt+1))
    if [ "$reload_attempt" -lt "3"  ]; then
      log_message "  Gateway not returning desired response, attempting hot reload"
      hot_reload "$gateway_base_url" "$gateway_api_credentials"
      sleep 2
    else
      log_message "  Maximum reload attempt reached"
      exit 1
    fi
  fi
  bootstrap_progress
done
log_ok

log_message "Checking Gateway 2 - Anonymous API access"
result=""
reload_attempt=0
while [ "$result" != "0" ]
do
  wait_for_response "$gateway2_base_url/basic-open-api/get" "200" "" 3
  result="$?"
  if [ "$result" != "0" ]
  then
    reload_attempt=$((reload_attempt+1))
    if [ "$reload_attempt" -lt "3"  ]; then
      log_message "  Gateway 2 not returning desired response, attempting hot reload"
      hot_reload "$gateway2_base_url" "$gateway2_api_credentials" 
      sleep 2
    else
      log_message "  Maximum reload attempt reached"
      exit 1
    fi
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
eval $(generate_docker_compose_command) restart tyk-dashboard 1> /dev/null 2>> logs/bootstrap.log
if [ "$?" != 0 ]; then
  echo "Error occurred when restarting Dashboard container"
  exit 1
fi
log_ok
bootstrap_progress

# Ngrok

ngrok_available=false
if ! grep -q "NGROK_AUTHTOKEN=" .env; then
  log_message "Ngrok auth token is not set, so Ngrok will not be available"
  log_message "To enable Ngrok, set the NGROK_AUTHTOKEN value in the Tyk Demo .env file"
else
  log_message "Getting Ngrok public URL for Tyk Gateway"
  ngrok_dashboard_url="http://localhost:4040"
  ngrok_ip_api_endpoint="$ngrok_dashboard_url/api/tunnels/tyk-gateway"
  log_message "  Getting data from $ngrok_ip_api_endpoint"
  ngrok_public_url=$(curl -s --show-error ${ngrok_ip_api_endpoint} 2>> logs/bootstrap.log | jq ".public_url" --raw-output)
  
  # we want to handle ngrok failure gracefully, such that it doesn't prevent the bootstrap from completing
  if [ "$?" != 0 ]; then
    log_message "  ERROR: Unable to get Ngrok configuration from $ngrok_ip_api_endpoint"
    ngrok_public_url="not configured"
  else
    if [ "$ngrok_public_url" = "" ]; then
      log_message "  ERROR: The Ngrok public URL is empty"
      ngrok_public_url="not configured"
    else
      log_message "  Ngrok public URL: $ngrok_public_url"
      ngrok_available=true
      log_ok  
    fi
  fi
fi

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
        Gateway API Key : $gateway2_api_credentials"
if [ "$ngrok_available" = "true" ]; then
  echo -e "
  ▽ Ngrok
             Public URL : $ngrok_public_url
          Dashboard URL : $ngrok_dashboard_url"
fi
