#!/bin/bash

# Contains functions useful for bootstrap scripts

spinner_chars="/-\|"
spinner_count=1

# Check that variables that are expected to be provided by sourcing script are avaiable.
# These variables should be set in the script that sources this file.
# Note: Use this function by calling it near the start of functions that require the variables listed in the variablesToCheck array.
function check_variables() {
  # add more variables to the array as needed
  variablesToCheck=("dashboard_base_url")
  errorFound=false

  for var in ${variablesToCheck[@]}; do
    if [ -z "${!var}" ]; then
      log_message "  ERROR: variable \"$var\" is not available in scripts/common.sh - this may cause errors. Please ensure that the script sourcing this library sets the value of this variable prior to calling any functions."
      errorFound=true
    fi
  done

  if $errorFound; then exit 1; fi
}

bootstrap_progress () {
  if [ ! -f .bootstrap/hide_progress ]; then
    printf "  Bootstrapping $deployment ${spinner_chars:spinner_count++%${#spinner_chars}:1} \r"
  fi
}

log_http_result () {
  if [ "$1" = "200" ] || [ "$1" = "201" ]
  then 
    log_ok
  else 
    log_message "  ERROR: $1"
    exit 1
  fi
}

log_json_result () {
  # the API returns variation of case for the status field and value, so we have to check them all
  local status=$(echo "$1" | jq 'if (.Status == "OK" or .Status == "Ok" or .Status == "ok" or .status == "OK" or .status == "Ok" or .status == "ok") then true else false end')

  if [ "$status" == "true" ]; then
    log_ok
  else
    local error_message=$(echo $1 | jq -r '.message // .Message // empty')
    if [ -n "$error_message" ]; then
      log_message "  ERROR: $error_message"
    else
      log_message "  ERROR: $(echo $1 | jq .)"
    fi
    exit 1
  fi
}

log_ok () {
  log_message "  Ok"
}

log_message () {
  echo "$(date -u) $@" >> logs/bootstrap.log
}

log_and_echo_message () {
  echo "$(date -u) $@" | tee -a logs/bootstrap.log
}

log_start_deployment () {
  log_message "START ▶ $deployment deployment bootstrap"
}

log_end_deployment () {
  log_message "END ▶ $deployment deployment bootstrap"
}

log_start_teardown () {
  log_message "START ▶ $deployment deployment teardown"
}

log_end_teardown () {
  log_message "END ▶ $deployment deployment teardown"
}

set_docker_environment_value () {
  local setting_current_value=$(grep "$1" .env)
  local setting_desired_value="$1=$2"
  if [ "$setting_current_value" == "" ]
  then
    # make sure .env file has an empty line before adding docker env var
    if [ ! -z "$(tail -c 1 .env)" ]
    then
      echo "" >> .env
    fi
    log_message "Adding Docker environment variable: $setting_desired_value"
    echo "$setting_desired_value" >> .env  
  else
    if [ "$setting_current_value" != "$setting_desired_value" ]
    then
      log_message "Updating Docker environment variable: $setting_desired_value"
      sed -i.bak 's/'"$setting_current_value"'/'"$setting_desired_value"'/g' .env
      rm .env.bak
    fi
  fi
}

delete_docker_environment_value () {
  local setting_key="$1"
  # don't include the "=" in the setting_key, it is automatically added
  sed -i.bak '/^'"$setting_key"'=/d' .env
  rm .env.bak
}

wait_for_response () {
  local url="$1"
  local status=""
  local desired_status="$2"
  local header="$3"
  local attempt_max="$4"
  local attempt_count=0
  local http_method="${5:-GET}" # default to GET method

  log_message "  Expecting $2 response from $1"

  while [ "$status" != "$desired_status" ]
  do
    attempt_count=$((attempt_count+1))

    # Build the curl command dynamically
    curl_command="curl -k -I -s -m5 -X $http_method $url"
    if [ -n "$header" ]; then
      curl_command="$curl_command -H \"$header\""
    fi

    # Execute the curl command and extract the status
    status=$(eval $curl_command 2>> logs/bootstrap.log | head -n 1 | cut -d$' ' -f2)

    if [ "$status" == "$desired_status" ]
    then
      log_message "    Attempt $attempt_count succeeded, received '$status'"
      return 0
    else
      if [ -n "$attempt_max" ]; then
        log_message "    Attempt $attempt_count of $attempt_max unsuccessful, received '$status'"
        # if max attempts reached, then exit with non-zero result
        if [ "$attempt_count" -eq "$attempt_max" ]; then
          log_message "    Maximum retry count reached. Aborting."
          return 1
        fi
      else
        log_message "    Attempt $attempt_count unsuccessful, received '$status'"
      fi
      sleep 2
    fi
  done
}

wait_for_file () {
  local file_path="$1"
  local container_name="$2"
  local try_max=10
  local try_count=0
  log_message "Waiting for $file_path to be present in $container_name"
  while true; do
    ((try_count++))
    if [ "$try_count" -gt "$try_max" ]; then
      echo "ERROR: Maximum retry count reached for file $file_path in container $container_name"
      exit 1
    fi

    docker exec $container_name sh -c "[ -s $file_path ]"
    if [ $? -eq 0 ]; then
      log_ok
      bootstrap_progress
      return 0
    else
      log_message "  File not present, waiting... $try_count/$try_max"
      bootstrap_progress
      sleep 2
    fi
  done
}

wait_for_file_local() {
  local file_path="$1"
  local try_max=10
  local try_count=0
  log_message "Waiting for $file_path to be present"
  while true; do
    ((try_count++))
    if [ "$try_count" -gt "$try_max" ]; then
      echo "ERROR: Maximum retry count reached for file $file_path"
      exit 1
    fi

    if [ -s $file_path ]; then
      log_ok
      bootstrap_progress
      return 0
    else
      log_message "  File not present, waiting... $try_count/$try_max"
      bootstrap_progress
      sleep 2
    fi
  done
}

hot_reload () {
  local gateway_host="$1"
  local gateway_secret="$2"
  local group="$3"
  local result=""

  if [ "$group" = "group" ]
  then
    log_message "  Sending group reload request to $1"
    result=$(curl $1/tyk/reload/group?block=true -s -k \
      -H "x-tyk-authorization: $2" | jq -r '.status')
  else
    log_message "  Sending reload request to $1"
    result=$(curl $1/tyk/reload?block=true -s -k \
      -H "x-tyk-authorization: $2" | jq -r '.status')
  fi

  if [ "$result" = "ok" ]
  then
    log_message "    Reload request successfully sent"
    return 0
  else
    log_message "    Reload request failed: $result"
    return 1
  fi
}

capture_container_logs () {
  eval $(generate_docker_compose_command) logs > logs/containers-$1-$(date +%s).log
}

set_context_data () {
  echo $5 > .context-data/$1_$2_$3_$4
}

get_context_data () {
  echo $(cat .context-data/$1_$2_$3_$4)
}

get_service_container_id () {
  # use function argument to get container id for service
  echo $(eval $(generate_docker_compose_command) ps -q $1)
}

get_service_container_data () {
  # 1st function argument get container id
  # 2nd function argument formats container data
  echo $(docker inspect $(get_service_container_id $1) --format "$2")
}

get_service_image_tag () {
  echo $(get_service_container_data $1 "{{ .Config.Image }}" | awk -F':' '{print $2}')
}

generate_docker_compose_command () {
  # create the docker compose command
  local command_docker_compose="docker compose --env-file `pwd`/.env"
  while read deployment; do
    command_docker_compose="$command_docker_compose -f deployments/$deployment/docker-compose.yml"
  done < .bootstrap/bootstrapped_deployments
  command_docker_compose="$command_docker_compose -p tyk-demo --project-directory `pwd`"

  echo "$command_docker_compose"
}

deployment_is_bootstrapped () {
  local deployment=$1
  # Check if deployment is listed in bootstrapped_deployments file
  if grep -Fxq "$deployment" .bootstrap/bootstrapped_deployments; then
    return 0
  else
    return 1
  fi
}

get_licence_payload () {
  # read licence line from .env file
  local licence_line=$(grep "$1=" .env)
  # extract licence JWT
  local encoded_licence_jwt=$(echo $licence_line | sed -E 's/^[A-Z_]+=(.+)$/\1/')
  # decode licence payload
  local decoded_licence_payload=$(decode_jwt $encoded_licence_jwt)

  echo $decoded_licence_payload
}

# This function checks if the provided licence contains any enterprise scope.
# Parameters:
#   $1 - The licence key to be checked.
# Returns:
#   0 - If the licence contains an enterprise scope.
#   1 - If the licence does not contain any enterprise scope.
check_licence_requires_enterprise () {
  licence_payload=$(get_licence_payload $1)
  licence_scope=$(echo $licence_payload | jq -r '.scope')

  # array of enterprise scopes
  # function returns true if any of these are matched
  enterprise_scopes=("streams")

  for enterprise_scope in "${enterprise_scopes[@]}"; do
    if [[ $licence_scope =~ (^|,)$enterprise_scope(,|$) ]]; then
      # enterprise scope found in licence
      return 0
    fi
  done

  # no enterprise scope found in licence
  return 1
}

check_licence_expiry () {
  local licence_payload=$(get_licence_payload $1)
  # read licence expiry
  local licence_expiry=$(echo $licence_payload | jq -r '.exp')
  # calculate the number of seconds remaining for the licence
  local licence_seconds_remaining=$(expr $licence_expiry - $(date '+%s'))
  # calculate the number of days remaining for the licence
  # do not make licence_days_remaining a local variable - this sets a global variable, allowing the value to be used elsewhere
  licence_days_remaining=$(expr $licence_seconds_remaining / 86400)
  
  # check if licence time remaining (in seconds) is less or equal to 0
  if [ "$licence_seconds_remaining" -le "0" ]; then
    log_message "  ERROR: Licence $1 has expired"
    if [[ "$1" == "DASHBOARD_LICENCE" ]]; then
      echo "ERROR: Tyk Dashboard licence has expired. Update DASHBOARD_LICENCE variable in .env file with a new licence."
    elif [[ "$1" == "MDCB_LICENCE" ]]; then
      echo "ERROR: Tyk MDCB licence has expired. Update MDCB_LICENCE variable in .env file with a new licence."
    else
      echo "ERROR: Licence $1 has expired."
    fi
    return 1; # does not meet requirements
  else
    if [[ "$licence_days_remaining" -le "7" ]]; then
      log_message "  WARNING: Licence $1 will expire in $licence_days_remaining days"
    else
      log_message "  Licence $1 has $licence_days_remaining days remaining"
    fi
    return 0; # does meet requirements
  fi
}

_decode_base64_url () {
  local len=$((${#1} % 4))
  local result="$1"
  if [ $len -eq 2 ]; then result="$1"'=='
  elif [ $len -eq 3 ]; then result="$1"'=' 
  fi
  echo "$result" | tr '_-' '/+' | base64 -d
}

decode_jwt () { _decode_base64_url $(echo -n $1 | cut -d "." -f ${2:-2}) | jq .; }

build_go_plugin () {
  local gateway_image_tag=$(get_service_image_tag "tyk-gateway")
  local go_plugin_filename=$1
  # each plugin must be in its own directory
  local go_plugin_directory="$PWD/deployments/tyk/volumes/tyk-gateway/plugins/go/$2"
  local go_plugin_path="$go_plugin_directory/$go_plugin_filename"
  local go_plugin_cache_directory="$PWD/.bootstrap/plugin-cache"
  local go_plugin_cache_version_directory="$go_plugin_cache_directory/$gateway_image_tag"
  local go_plugin_cache_file_path="$go_plugin_cache_version_directory/$go_plugin_filename"

  # create cache directories if missing
  if [ ! -d "$go_plugin_cache_directory" ]; then
    mkdir $go_plugin_cache_directory
  fi
  if [ ! -d "$go_plugin_cache_version_directory" ]; then
    mkdir $go_plugin_cache_version_directory
  fi

  log_message "Checking for Go plugin $go_plugin_filename $gateway_image_tag in cache"
  # build plugin if it does not exist in the cache
  if [ ! -f $go_plugin_cache_file_path ]; then
    log_message "  Not found. Building Go plugin $go_plugin_path using tag $gateway_image_tag"
    # default Go build targets
    local goarch="amd64"
    local goos="linux"
    # get the current platform
    local platform=$(uname -m)
    log_message "  Current hardware platform: $platform"
    if [ "$platform" == 'arm64' ]; then
      goarch=$platform
    fi
    log_message "  Target Go Platform: $goos/$goarch"
    docker run --rm -v $go_plugin_directory:/plugin-source -e GOOS=$goos -e GOARCH=$goarch --platform linux/amd64 tykio/tyk-plugin-compiler:$gateway_image_tag $go_plugin_filename
    local plugin_container_exit_code="$?"
    if [[ "$plugin_container_exit_code" -ne "0" ]]; then
      log_message "  ERROR: Tyk Plugin Compiler container returned error code: $plugin_container_exit_code"
      exit 1
    fi
    # the .so file created by the plugin build container includes the target release version and architecture e.g. example-go-plugin_v4.1.0_linux_amd64.so
    # we need to remove these so that the file name matches what's in the API definition e.g. example-go-plugin.so
    rm $go_plugin_directory/$go_plugin_filename
    mv $go_plugin_directory/*.so $go_plugin_directory/$go_plugin_filename
    # copy to cache, to enable built plugins to be reused across bootstraps
    cp $go_plugin_directory/*.so $go_plugin_cache_version_directory

    # limit the number of plugin caches to prevent uncontrolled growth
    local PLUGIN_CACHE_MAX_SIZE=$(grep -E '^PLUGIN_CACHE_MAX_SIZE=[0-9]+' .env | cut -d '=' -f2)
    PLUGIN_CACHE_MAX_SIZE=${PLUGIN_CACHE_MAX_SIZE:-3}
    local plugin_cache_count=$(find "$go_plugin_cache_directory" -maxdepth 1 -type d -not -path "$go_plugin_cache_directory" | wc -l | xargs)
    log_message "  Plugin cache used/max: $plugin_cache_count/$PLUGIN_CACHE_MAX_SIZE"
    if [ "$plugin_cache_count" -gt "$PLUGIN_CACHE_MAX_SIZE" ]; then
      oldest_plugin_cache_path=$(find "$go_plugin_cache_directory" -type d -not -path "$go_plugin_cache_directory" -exec ls -ld -ltr {} + | head -n 1 | awk '{print $9}')
      if [ -n "$oldest_plugin_cache_path" ]; then
        log_message "  Pruning oldest plugin cache $oldest_plugin_cache_path"
        rm "$oldest_plugin_cache_path/*.so"
        rm -r "$oldest_plugin_cache_path"
      fi
    fi
  else
    log_message "  Found. Copying Go plugin $go_plugin_filename $gateway_image_tag from cache"
    cp $go_plugin_cache_file_path $go_plugin_directory/$go_plugin_filename
    # note: if you want to force a recompile of the plugin .so file, delete the .so file from the applicable .bootstrap/plugin-cache directory
  fi
  log_ok
}

create_organisation () {
  local organisation_data_path="$1"
  local api_key="$2"
  local data_group="$3"
  local index="$4"
  local organisation_id=$(jq -r '.id' $organisation_data_path)
  local organisation_name=$(jq -r '.owner_name' $organisation_data_path)
  local portal_hostname=$(jq -r '.cname' $organisation_data_path)

  check_variables

  # create organisation in Tyk Dashboard database
  log_message "  Creating Organisation: $organisation_name"
  local api_response=$(curl $dashboard_base_url/admin/organisations/import -s \
    -H "admin-auth: $api_key" \
    -d @$organisation_data_path 2>> logs/bootstrap.log)

  # validate result
  log_json_result "$api_response"
  
  # add details to context data
  set_context_data "$data_group" "organisation" "$index" "id" "$organisation_id"
  set_context_data "$data_group" "organisation" "$index" "name" "$organisation_name"
  set_context_data "$data_group" "portal" "$index" "hostname" "$portal_hostname"

  log_message "    Name: $organisation_name"
  log_message "    Id: $organisation_id"
  log_message "    Portal Hostname: $portal_hostname"
}

create_cert () {
  local cert_data_path="$1"
  local api_key="$2"
  local cert_name=$(echo $(basename "$cert_data_path") | cut -d'-' -f3 | cut -d'.' -f1)
  check_variables

  # create cert in Tyk Dashboard database
  log_message "  Creating Cert: $cert_name"
  local api_response=$(curl $dashboard_base_url/api/certs -s \
    -H "Authorization: $api_key" \
    -F "cert=@$cert_data_path;type=application/x-x509-ca-cert" 2>> logs/bootstrap.log)

  # Note that cert ids are a combination of the org id and the cert fingerprint, making them predicatable and able to be referenced from other objects

  # validate result
  log_json_result "$api_response"
}

create_dashboard_user () {
  local dashboard_user_data_path="$1"
  local api_key="$2"
  local data_group="$3"
  local index="$4"
  local dashboard_user_password=$(jq -r '.password' $dashboard_user_data_path)
  
  check_variables
  
  # create user in Tyk Dashboard database
  log_message "  Creating Dashboard User: $(jq -r '.email_address' $dashboard_user_data_path)"
  local api_response=$(curl $dashboard_base_url/admin/users -s \
    -H "admin-auth: $api_key" \
    -d @$dashboard_user_data_path 2>> logs/bootstrap.log)

  # validate result
  log_json_result "$api_response"

  # extract user data from response
  local dashboard_user_id=$(echo $api_response | jq -r '.Meta.id')
  local dashboard_user_email=$(echo $api_response | jq -r '.Meta.email_address')
  local dashboard_user_api_key=$(echo $api_response | jq -r '.Meta.access_key')
  local dashboard_user_organisation_id=$(echo $api_response | jq -r '.Meta.org_id')

  # log user data
  log_message "    Id: $dashboard_user_id"
  log_message "    Email: $dashboard_user_email"
  log_message "    API Key: $dashboard_user_api_key"
  log_message "    Organisation Id: $dashboard_user_organisation_id"

  # add data to global variables and context data
  set_context_data "$data_group" "dashboard-user" "$index" "email" "$dashboard_user_email"
  set_context_data "$data_group" "dashboard-user" "$index" "password" "$dashboard_user_password"
  set_context_data "$data_group" "dashboard-user" "$index" "api-key" "$dashboard_user_api_key"

  # reset the password
  log_message "  Resetting password for $dashboard_user_email"
  api_response=$(curl $dashboard_base_url/api/users/$dashboard_user_id/actions/reset -s \
    -H "authorization: $dashboard_user_api_key" \
    --data-raw '{
        "new_password":"'$dashboard_user_password'",
        "user_permissions": { "IsAdmin": "admin" }
      }' 2>> logs/bootstrap.log)

  log_json_result "$api_response"

  log_message "    Password: $dashboard_user_password"
}

create_user_group () {
  local user_group_data_path="$1"
  local api_key="$2"
  local data_group="$3"
  local index="$4"
  local user_group_name=$(jq -r '.name' $user_group_data_path)

  check_variables

  # create user group in Tyk Dashboard database
  log_message "  Creating User Group: $user_group_name"
  local api_response=$(curl $dashboard_base_url/api/usergroups -s \
    -H "Authorization: $api_key" \
    -d @$user_group_data_path 2>> logs/bootstrap.log)

  # validate result
  log_json_result "$api_response"
  
  # extract data from response
  local user_group_id=$(echo "$api_response" | jq -r '.Meta')

  set_context_data "$data_group" "dashboard-user-group" "$index" "id" "$user_group_id"

  log_message "    Id: $user_group_id"
}

create_webhook () {
  local webhook_data_path="$1"
  local api_key="$2"
  local webhook_name=$(jq -r '.name' $webhook_data_path)

  check_variables

  # create webhook in Tyk Dashboard database
  log_message "  Creating Webhook: $webhook_name"
  local api_response=$(curl $dashboard_base_url/api/hooks -s \
    -H "Authorization: $api_key" \
    -d @$webhook_data_path 2>> logs/bootstrap.log)

  # validate result
  log_json_result "$api_response"

  # the /api/hooks endpoint doesn't return the webhook id, so we can't save any context data
}

initialise_portal () {
  local organisation_id="$1"
  local api_key="$2"

  check_variables

  log_message "  Creating default settings"
  local api_response=$(curl $dashboard_base_url/api/portal/configuration -s \
    -H "Authorization: $api_key" \
    -d "{}" 2>> logs/bootstrap.log)
  log_json_result "$api_response"

  log_message "  Initialising Catalogue"
  api_response=$(curl $dashboard_base_url/api/portal/catalogue -s \
    -H "Authorization: $api_key" \
    -d '{"org_id": "'$organisation_id'"}' 2>> logs/bootstrap.log)
  log_json_result "$api_response"
  
  catalogue_id=$(echo "$api_response" | jq -r '.Message')
  log_message "    Id: $catalogue_id"
}

create_portal_page () {
  local page_data_path="$1"
  local api_key="$2"
  local page_title=$(jq -r '.title' $page_data_path)

  check_variables

  log_message "  Creating Page: $page_title"

  log_json_result "$(curl $dashboard_base_url/api/portal/pages -s \
    -H "Authorization: $api_key" \
    -d @$page_data_path 2>> logs/bootstrap.log)"
}

create_portal_developer () {
  local developer_data_path="$1"
  local api_key="$2"
  local index="$3"
  local developer_email=$(jq -r '.email' $developer_data_path)
  local developer_password=$(jq -r '.password' $developer_data_path)

  check_variables

  log_message "  Creating Developer: $developer_email"
  local api_response=$(curl $dashboard_base_url/api/portal/developers -s \
    -H "Authorization: $api_key" \
    -d @$developer_data_path 2>> logs/bootstrap.log)
  log_json_result "$api_response"

  set_context_data "$data_group" "portal-developer" "$index" "email" "$developer_email"
  set_context_data "$data_group" "portal-developer" "$index" "password" "$developer_password"

  log_message "    Password: $developer_password"
}

create_portal_graphql_documentation () {
  local api_key="$1"
  local documentation_title="$2"
  
  check_variables

  log_message "  Creating Documentation: $documentation_title"
  local api_response=$(curl $dashboard_base_url/api/portal/documentation -s \
    -H "Authorization: $api_key" \
    -d '{"api_id":"","doc_type":"graphql","documentation":"graphql"}' \
      2>> logs/bootstrap.log)

  log_json_result "$api_response"

  local documentation_id=$(echo "$api_response" | jq -r '.Message')

  log_message "    Id: $documentation_id"

  echo "$documentation_id"
}

create_portal_documentation () {
  local documentation_data_path="$1"
  local api_key="$2"
  local documentation_title=$(jq -r '.info.title' $documentation_data_path)
  
  check_variables

  log_message "  Creating Documentation: $documentation_title"

  local encoded_documentation=$(cat $documentation_data_path | base64)
  local documentation_payload=$(jq --arg documentation "$encoded_documentation" '.documentation = $documentation' deployments/tyk/data/tyk-dashboard/dashboard-api-portal-documentation-create-template.json)

  local api_response=$(curl $dashboard_base_url/api/portal/documentation -s \
    -H "Authorization: $api_key" \
    -d "$documentation_payload" \
      2>> logs/bootstrap.log)

  log_json_result "$api_response"

  local documentation_id=$(echo "$api_response" | jq -r '.Message')

  log_message "    Id: $documentation_id"

  echo "$documentation_id"
}

create_portal_catalogue () {
  local catalogue_data_path="$1"
  local api_key="$2"
  local documentation_id="$3"
  local catalogue_name=$(jq -r '.name' $catalogue_data_path)

  check_variables

  log_message "  Adding Catalogue Entry: $catalogue_name"

  # get the existing catalogue
  local catalogue="$(curl $dashboard_base_url/api/portal/catalogue -s \
    -H "Authorization: $api_key" 2>> logs/bootstrap.log)"

  # add documentation id to new catalogue
  local new_catalogue=$(jq --arg documentation_id "$documentation_id" '.documentation = $documentation_id' $catalogue_data_path)

  # update the catalogue with the new catalogue entry
  local updated_catalogue=$(jq --argjson new_catalogue "[$new_catalogue]" '.apis += $new_catalogue' <<< "$catalogue")

  log_json_result "$(curl $dashboard_base_url/api/portal/catalogue -X 'PUT' -s \
    -H "Authorization: $api_key" \
    -d "$updated_catalogue" 2>> logs/bootstrap.log)"
}

read_api () {
  local api_key="$1"
  local api_id="$2"
  local api_response="$(curl $dashboard_base_url/api/apis/$api_id -s \
    -H "authorization: $api_key" 2>> logs/bootstrap.log)"
  echo "$api_response"
}

create_api2 () {
  local api_data_path="$1"
  local dashboard_api_key="$2"
  local api_data="$(cat $api_data_path)"
  local api_name=""
  local api_id=""
  # API data format differs depending on type of API, which we can determine by the file name containing 'oas'
  local api_is_oas=$([[ $api_data_path =~ api-oas-[a-z0-9]+\.json$ ]] && echo true || echo false)
  local api_endpoint="$dashboard_base_url/api/apis"

  check_variables

  # get the id and name of the API
  if [ "$api_is_oas" == true ]; then
    # OAS API
    api_name=$(jq -r '.["x-tyk-api-gateway"].info.name' $api_data_path)
    api_id=$(jq -r '.["x-tyk-api-gateway"].info.id' $api_data_path)    
    # import endpoint differs between classic and OAS APIs
    api_endpoint="$api_endpoint/oas"
    log_message "  Creating OAS API: $api_name"
  else
    # Tyk API 
    api_name=$(jq -r '.api_definition.name' $api_data_path)
    api_id=$(jq -r '.api_definition.api_id' $api_data_path)
    log_message "  Creating Classic API: $api_name"
  fi
  log_message "    Id: $api_id"

  # Update any webhook references - these need updating because webhooks ids are not static
  # TODO: create OAS version for this, when needed
  local webhook_reference_count=$(jq '.hook_references | length' $api_data_path)
  if [ "$webhook_reference_count" -gt "0" ]; then
    local webhook_data=$(curl $dashboard_base_url/api/hooks?p=-1 -s \
      -H "Authorization: $dashboard_api_key" | \
      jq '.hooks[]')

    # loop through each webhook referenced in the API
    while read webhook_name; do
      log_message "    Updating Webhook Reference: $webhook_name"

      local new_webhook_id=$(jq -r --arg webhook_name "$webhook_name" 'select ( .name == $webhook_name ) .id' <<< "$webhook_data")
      
      # update the hook reference id, matching by the webhook name
      api_data=$(jq --arg webhook_id "$new_webhook_id" --arg webhook_name "$webhook_name" '(.hook_references[] | select(.hook.name == $webhook_name) .hook.id) = $webhook_id' <<< "$api_data")

      # update the AuthFailure event handler, if it exists
      # if more events are added then additional code will be needed to handle them
      api_data=$(jq --arg webhook_id "$new_webhook_id" --arg webhook_name "$webhook_name" '(.api_definition.event_handlers.events.AuthFailure[]? | select(.handler_meta.name == $webhook_name) .handler_meta.id) = $webhook_id' <<< "$api_data")

      log_message "      Id: $new_webhook_id"
    done <<< "$(jq -c -r '.hook_references[].hook.name' $api_data_path)"
  fi

  local api_response="$(curl $api_endpoint -s \
    -H "authorization: $dashboard_api_key" \
    -d "$api_data" 2>> logs/bootstrap.log)"

  log_json_result "$api_response"
}

create_api() {
  local api_data_path="$1"
  local dashboard_api_key="$2"

  if [[ -z "$api_data_path" || -z "$dashboard_api_key" ]]; then
    log_message "ERROR: Missing required parameters. Usage: create_api <api_data_path> <dashboard_api_key>"
    return 1
  fi

  if [[ ! -f "$api_data_path" ]]; then
    log_message "ERROR: File not found: $api_data_path"
    return 1
  fi

  # check that required variables are set
  check_variables

  local api_name=""
  local api_id=""
  local api_type=""
  local api_endpoint="$dashboard_base_url/api/apis"
  local extra_headers=()

  # Read JSON data once
  local api_data=$(cat "$api_data_path")

  # Determine API type based on JSON structure
  if jq -e 'has("x-tyk-api-gateway")' <<< "$api_data" > /dev/null; then
    api_name=$(jq -r '."x-tyk-api-gateway".info.name' <<< "$api_data")
    api_id=$(jq -r '."x-tyk-api-gateway".info.id' <<< "$api_data")

    if jq -e 'has("x-tyk-streaming")' <<< "$api_data" > /dev/null; then
      api_type="Streams"
      api_endpoint="$api_endpoint/streams"
      extra_headers=("-H" "Content-Type: application/vnd.tyk.streams.oas")
    else
      api_type="OAS"
      api_endpoint="$api_endpoint/oas"
    fi
  elif jq -e 'has("api_definition")' <<< "$api_data" > /dev/null; then
    api_type="Classic"
    api_name=$(jq -r '.api_definition.name' <<< "$api_data")
    api_id=$(jq -r '.api_definition.api_id' <<< "$api_data")
  else
    log_message "ERROR: Unable to determine API type: $api_data_path"
    return 1
  fi

  log_message "  Creating API: $api_name"
  log_message "    Type: $api_type"
  log_message "    ID: $api_id"

  # Handle webhook references
  local webhook_reference_count=$(jq '.hook_references | length // 0' <<< "$api_data")
  if [[ "$webhook_reference_count" -gt 0 ]]; then
    local webhook_data=$(curl -s "$dashboard_base_url/api/hooks?p=-1" \
      -H "Authorization: $dashboard_api_key" | jq '.hooks[]')

    while read -r webhook_name; do
      log_message "  Updating Webhook Reference: $webhook_name"
      local new_webhook_id=$(jq -r --arg webhook_name "$webhook_name" 'select(.name == $webhook_name) .id' <<< "$webhook_data")

      if [[ -z "$new_webhook_id" ]]; then
        log_message "ERROR: Webhook not found: $webhook_name"
        continue
      fi

      api_data=$(jq --arg webhook_id "$new_webhook_id" --arg webhook_name "$webhook_name" \
        '(.hook_references[] | select(.hook.name == $webhook_name) .hook.id) = $webhook_id' <<< "$api_data")

      if [[ "$api_type" == "Classic" ]]; then
        api_data=$(jq --arg webhook_id "$new_webhook_id" --arg webhook_name "$webhook_name" \
          '(.api_definition.event_handlers.events.AuthFailure[]? | select(.handler_meta.name == $webhook_name) .handler_meta.id) = $webhook_id' <<< "$api_data")
      fi

      log_message "    ID: $new_webhook_id"
    done < <(jq -c -r '.hook_references[].hook.name' <<< "$api_data")
  fi

  # Send API creation request
  local api_response=$(curl -s "$api_endpoint" \
    -H "Authorization: $dashboard_api_key" \
    "${extra_headers[@]}" \
    -d "$api_data" 2>> logs/bootstrap.log)

  if [[ -z "$api_response" ]]; then
    log_message "ERROR: Empty response from API."
    return 1
  fi

  log_json_result "$api_response"
}

create_policy () {
  local policy_data_path="$1"
  local dashboard_api_key="$2"
  local policy_name=$(jq -r '.name' $policy_data_path)
  local policy_id=$(jq -r '._id' $policy_data_path)

  check_variables

  log_message "  Creating Policy: $policy_name"

  api_response="$(curl $dashboard_base_url/api/portal/policies -s \
    -H "authorization: $dashboard_api_key" \
    -d @$policy_data_path 2>> logs/bootstrap.log)"

  local result_id=$(jq -r '.Message' <<< "$api_response")
  local result_status=$(jq -r '.Status' <<< "$api_response")

  log_message "    ID: $result_id"
  log_message "    Status: $result_status"

  log_json_result "$api_response"
}

create_basic_key () {
  local basic_key_data_path="$1"
  local api_key="$2"
  local file_name="$(basename $basic_key_data_path)"
  # username is taken from the filename, using the 3rd hypenated segment and excluding the extension e.g. "basic-1-basic_auth_username.json" results in "basic_auth_username"
  local username="$(echo "$file_name" | cut -d. -f1 | cut -d- -f3)"
  local password="$(jq -r '.basic_auth_data.password' $basic_key_data_path)"

  check_variables

  if [[ "$username" == "" ]]; then
    log_message "ERROR: Could not extract username from filename $file_name"
    exit 1
  fi

  log_message "  Adding Basic Key: $username"

  local api_response_status_code="$(curl $dashboard_base_url/api/apis/keys/basic/$username -s -w "%{http_code}" -o /dev/null \
    -H "Authorization: $api_key" \
    -d @$basic_key_data_path 2>> logs/bootstrap.log)"

  # custom validation
  if [[ "$api_response_status_code" == "200" ]]; then
    log_ok
    log_message "    Password: $password"
  else
    log_message "ERROR: Could not create basic key. API response status code: $api_response_status_code."
    exit 1
  fi
}

create_bearer_token () {
  local bearer_token_data_path="$1"
  local api_key="$2"
  local file_name="$(basename $bearer_token_data_path)"
  # key name is taken from the filename, using the 4th hypenated segment and excluding the extension e.g. "bearer-token-1-mytoken.json" results in "mytoken"
  local key_name="$(echo "$file_name" | cut -d. -f1 | cut -d- -f4)"

  check_variables

  if [[ "$key_name" == "" ]]; then
    log_message "ERROR: Could not extract key name from filename $file_name"
    exit 1
  fi

  log_message "  Adding Bearer Token: $key_name"

  # currently hard-coded to target a single gateway "$gateway_base_url"
  local api_response=$(curl $gateway_base_url/tyk/keys/$key_name -s \
    -H "x-tyk-authorization: $api_key" \
    -d @$bearer_token_data_path 2>> logs/bootstrap.log)

  local response_status="$(jq -r '.status' <<< "$api_response")"

  # custom validation
  if [[ "$response_status" == "ok" ]]; then
    log_ok
    log_message "    Key: $(jq -r '.key' <<< "$api_response")"
    log_message "    Hash: $(jq -r '.key_hash' <<< "$api_response")"
  else
    log_message "ERROR: Could not create bearer token. API response returned $api_response."
    exit 1
  fi
}

create_bearer_token_dash () {
  local bearer_token_data_path="$1"
  local api_key="$2"
  local file_name="$(basename $bearer_token_data_path)"
  # key name is taken from the filename, using the 4th hypenated segment and excluding the extension e.g. "bearer-token-1-mytoken.json" results in "mytoken"
  local key_name="$(echo "$file_name" | cut -d. -f1 | cut -d- -f4)"

  check_variables

  if [[ "$key_name" == "" ]]; then
    log_message "ERROR: Could not extract key name from filename $file_name"
    exit 1
  fi

  log_message "  Adding Bearer Token (dash): $key_name"

  local api_response=$(curl $dashboard_base_url/api/keys -s \
    -H "Authorization: $api_key" \
    -H 'Content-Type: application/json' \
    -d @$bearer_token_data_path 2>> logs/bootstrap.log)

  # custom validation
  if echo "$api_response" | jq -e 'has("key_id") and (.key_id | length > 0)' > /dev/null; then
    log_ok
    log_message "    Key: $(jq -r '.key_id' <<< "$api_response")"
    log_message "    Hash: $(jq -r '.key_hash' <<< "$api_response")"
  else
    log_message "ERROR: Could not create bearer token. API response returned $api_response."
    exit 1
  fi
}

delete_bearer_token_dash () {
  local key_name="$1"
  local api_id="$2"
  local api_key="$3"

  log_message "  Deleting Bearer Token: $key_name"

  local api_response=$(curl $dashboard_base_url/api/apis/$api_id/keys/$key_name -s \
    -X DELETE \
    -H "Authorization: $api_key" 2>> logs/bootstrap.log)

  local response_status="$(jq -r '.Status' <<< "$api_response")"

  # custom validation
  if [[ "$response_status" == "OK" ]]; then
    log_ok
  else
    log_message "ERROR: Could not delete bearer token. API response returned $api_response."
    exit 1
  fi
}

delete_bearer_token() {
  local key_name="$1"
  local api_key="$2"

  log_message "  Deleting Bearer Token: $key_name"

  local api_response=$(curl $gateway_base_url/tyk/keys/$key_name -s \
    -X DELETE \
    -H "x-tyk-authorization: $api_key" 2>> logs/bootstrap.log)

  local response_status="$(jq -r '.status' <<< "$api_response")"

  # custom validation
  if [[ "$response_status" == "ok" ]]; then
    log_ok
  else
    log_message "ERROR: Could not delete bearer token. API response returned $api_response."
    exit 1
  fi
}

create_oauth_client () {
  local oauth_client_data_path="$1"
  local api_key="$2"
  local api_id=$(cat $oauth_client_data_path | jq -r '.api_id')
  local client_id=$(cat $oauth_client_data_path | jq -r '.client_id')
  local client_secret=$(cat $oauth_client_data_path | jq -r '.secret')

  check_variables

  log_message "  Adding OAuth Client: $client_id"

  local api_response=$(curl $dashboard_base_url/api/apis/oauth/$api_id -s \
    -H "Authorization: $api_key" \
    -d @$oauth_client_data_path 2>> logs/bootstrap.log)

  local response_client_id=$(jq -r '.client_id' <<< "$api_response")
  local response_client_secret=$(jq -r '.secret' <<< "$api_response")

  # custom validation
  if [[ "$response_client_id" == "$client_id" ]] && [[ "$response_client_secret" == "$client_secret" ]]; then
    log_ok
    log_message "    Secret: $client_secret"
  else
    log_message "ERROR: API response does not contain expected OAuth client data. API response returned $api_response."
    exit 1
  fi
}

wait_for_api_loaded () {
  local api_id="$1"
  local gateway_url="$2"
  local gateway_auth="$3"
  local target_api_result=""
  local attempt_count=0
  log_message "  Waiting for API $api_id to be available on $gateway_url"
  while [ "$target_api_result" != "200" ]; do
    attempt_count=$((attempt_count+1))
    if [ "$attempt_count" -gt "10"  ]; then
      echo "ERROR: Target API ($api_id) not available on Gateway ($gateway_url) - max retry reached"
      exit 1
    fi
    target_api_result=$(curl "$gateway_url/tyk/apis/$api_id" -o /dev/null -s -w "%{http_code}\n" -H "x-tyk-authorization: $gateway_auth")
    if [ "$target_api_result" != "200" ]; then
      log_message "  Waiting for API $api_id to become available on $gateway_url..."
      bootstrap_progress
      sleep 2
    else
      log_message "  Found API $api_id on $gateway_url"
    fi
  done
}

wait_for_policy_loaded () {
  local policy_id="$1"
  local gateway_url="$2"
  local gateway_auth="$3"
  local target_api_result=""
  local attempt_count=0
  log_message "  Waiting for Policy $policy_id to be available on $gateway_url"
  while [ "$target_api_result" != "200" ]; do
    attempt_count=$((attempt_count+1))
    if [ "$attempt_count" -gt "10"  ]; then
      echo "ERROR: Target Policy ($policy_id) not available on Gateway ($gateway_url) - max retry reached"
      exit 1
    fi
    target_api_result=$(curl "$gateway_url/tyk/policies/$policy_id" -o /dev/null -s -w "%{http_code}\n" -H "x-tyk-authorization: $gateway_auth")
    if [ "$target_api_result" != "200" ]; then
      log_message "  Waiting for $policy_id to become available on $gateway_url..."
      bootstrap_progress
      sleep 2
    else
      log_message "  Found Policy $policy_id on $gateway_url"
    fi
  done
}


wait_for_liveness () {
  local status_endpoint="${1:-http://tyk-gateway.localhost:8080/hello}"
  local attempt_count=0

  log_message "Waiting for Gateway, Dashboard and Redis to be up and running"
  log_message "  Gateway status endpoint: $status_endpoint"

  while true; do
    attempt_count=$((attempt_count+1))

    #Check Gateway, Redis and Dashboard status
    local status_response=$(curl $status_endpoint -s)
    local gw_status=$(echo "$status_response" | jq -r '.status')
    local dash_status=$(echo "$status_response" | jq -r '.details.dashboard.status')
    local redis_status=$(echo "$status_response" | jq -r '.details.redis.status')

    if [[ "$gw_status" = "pass" ]] && [[ "$dash_status" = "pass" ]] && [[ "$redis_status" = "pass" ]]
    then
      log_message "    Attempt $attempt_count succeeded: Gateway, Dashboard and Redis all running"
      break
    else
      log_message "    Attempt $attempt_count unsuccessful: gw status = '$gw_status', dashboard status = '$dash_status', redis status = '$redis_status'"
    fi

    sleep 2
  done
}

wait_for_status() {
  local url="$1"
  local expected_status="$2"
  local json_path="$3"
  local expected_value="$4"
  local max_retries="${5:-5}"
  local delay="${6:-1}"
  local attempt=0
  local response
  local http_status

  if [[ -z "$url" || -z "$expected_status" ]]; then
    echo "Usage: wait_for_status <url> <expected_status> [json_path] [expected_value] [max_retries] [delay]"
    exit 1
  fi

  log_message "Checking status for URL: $url with expected HTTP status: $expected_status"
  if [[ -n "$json_path" && -n "$expected_value" ]]; then
    log_message "Validating JSON path: $json_path with expected value: $expected_value"
  fi
  
  while (( attempt < max_retries )); do
    # Perform the curl request
    response=$(curl -s -w "\n%{http_code}" "$url")
    http_status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$ d')

    # Check HTTP status
    if [[ "$http_status" == "$expected_status" ]]; then
      # Optional body validation
      if [[ -n "$json_path" && -n "$expected_value" ]]; then
        actual_value=$(echo "$body" | jq -r "$json_path" 2>/dev/null)
        if [[ "$actual_value" == "$expected_value" ]]; then
          log_message "  PASS: Status check passed."
          return 0
        else
          log_message "  Got JSON value: $actual_value"
        fi
      else
        log_message "  PASS: Status check passed."
        return 0
      fi
    else
      log_message "  Got HTTP status: $http_status"
    fi

    log_message "  Attempt $((attempt + 1))/$max_retries failed. Retrying in $delay seconds..."
    sleep "$delay"
    ((attempt++))
  done

  log_message "  FAIL: Status check failed after $max_retries attempts."
  return 1
}

check_for_grpcurl () {
  # Check if grpcurl is installed
  if ! command -v grpcurl &> /dev/null
  then
      echo "grpcurl is not installed. Please install grpcurl to proceed:"
      echo "brew install grpcurl"
      exit 1
  fi
}

check_for_websocat () {
  # Check if websocat is installed
  if ! command -v websocat &> /dev/null
  then
      echo "websocat is not installed. Please install websocat to proceed:"
      echo "brew install websocat"
      exit 1
  fi
}

api_has_section () {
  local json_file="$1"
  local section="$2"
  if jq -e 'has("'"$section"'")' "$json_file" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

licence_has_scope () {
  local licence_payload scope scopes search_term
  
  licence_name="$1"
  search_term="$2"
  licence_payload=$(get_licence_payload "$licence_name") || return 2
  
  # Check if jq command succeeds
  scopes=$(echo "$licence_payload" | jq -r '.scope') || return 2

  # Direct return of grep status
  echo "$scopes" | tr ',' '\n' | grep -Fx "$search_term" > /dev/null
}

licence_allowed_nodes () {
  local licence_name="$1"
  local licence_payload=$(get_licence_payload $licence_name)
  # Extract the 'allowed_nodes' value and split by commas to count the elements
  echo "$licence_payload" | jq -r '.allowed_nodes' | tr ',' '\n' | wc -l
}

create_enterprise_portal_page () {
  local page_data_dir_path="$1"
  local api_key="$2"

  if [ -z "$portal_base_url" ]; then
    log_message "ERROR: portal_base_url is not set. Please ensure that the sourcing script defines it before calling this function."
    return 1
  fi

  if [ -z "$api_key" ]; then
    log_message "ERROR: api_key is not set. Please ensure it is provided before calling this function."
    return 1
  fi

  log_message "Creating portal page from path: $page_data_dir_path"
  if [[ ! -d "$page_data_dir_path" ]]; then
    log_message "ERROR: Path must be a directory"
    return 1
  fi

  page_data_path="$page_data_dir_path/page.json"

  if [[ ! -f $page_data_path ]]; then
    log_message "ERROR: Missing portal page file $page_data_path"
    return 1 # can't continue without page.json
  fi

  log_message "  Processing portal page: $page_data_path"

  local page_title=$(jq -r '.Title' "$page_data_path")
  local page_path=$(jq -r '.Path' "$page_data_path")

  if [[ -z "$page_title" || -z "$page_path" ]]; then
    log_message "ERROR: Failed to extract Title or Path from $page_data_path"
    return 1
  fi

  log_message "    Title: $page_title"
  log_message "    URL path: $page_path"

  local api_response=$(curl "$portal_base_url/portal-api/pages" -s -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: $api_key" \
    -d @$page_data_path 2>> logs/bootstrap.log)

  local api_response_body=$(echo "$api_response" | sed '$d')       # Body is all lines except the last
  local api_response_status=$(echo "$api_response" | tail -n1)     # Last line is the status code

  # Look for 201 - Created
  if [[ "$api_response_status" == "201" ]]; then 
    local page_id=$(echo "$api_response_body" | jq -r '.ID')
    log_message "  Page created with ID: $page_id"
  else
    log_message "ERROR: Could not create portal page. API response status $api_response_status, body: $api_response_body"
    return 1
  fi

  for content_block_data_path in $page_data_dir_path/content-block-*.json; do
    if [[ -f "$content_block_data_path" ]]; then
      log_message "  Processing content block: $content_block_data_path"
      local content_block_name=$(jq -r '.Name' "$content_block_data_path")
      local content_block_id=""

      api_response=$(curl "$portal_base_url/portal-api/pages/$page_id/content-blocks" -s \
        -H "Authorization: $api_key" 2>> logs/bootstrap.log)

      # Page templates come with pre-existing content blocks. So we must check if the block already exists either update or create.
      if echo "$api_response" | jq -e --arg block_name "$content_block_name" '.[] | select(.Name == $block_name)' > /dev/null; then
        content_block_id=$(echo "$api_response" | jq -r --arg block_name "$content_block_name" '.[] | select(.Name == $block_name) | .ID')
        log_message "    Content block '$content_block_name' already exists with ID '$content_block_id', updating"

        api_response=$(curl "$portal_base_url/portal-api/pages/$page_id/content-blocks/$content_block_id" -X PUT -s -w "\n%{http_code}" \
          -H "Content-Type: application/json" \
          -H "Authorization: $api_key" \
          -d @$content_block_data_path 2>> logs/bootstrap.log)
      else
        log_message "    Content block '$content_block_name' does not exist, creating"

        api_response=$(curl "$portal_base_url/portal-api/pages/$page_id/content-blocks" -s -w "\n%{http_code}" \
          -H "Content-Type: application/json" \
          -H "Authorization: $api_key" \
          -d @$content_block_data_path 2>> logs/bootstrap.log)

        content_block_id=$(echo "$api_response" | jq -r '.ID')
      fi

      api_response_body=$(echo "$api_response" | sed '$d')
      api_response_status=$(echo "$api_response" | tail -n1)

      if [[ "$api_response_status" == "200" || "$api_response_status" == "201" ]]; then
        log_message "    Upserted content block '$content_block_name', with ID '$content_block_id'"
      else
        log_message "ERROR: Could not upsert content block '$content_block_name'. API response status $api_response_status, body: $api_response_body"
        return 1
      fi
    fi
  done
}

# Prepare log directory and bootstrap log files
prepare_bootstrap_log() {
  local base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local log_directory_path="$base_dir/logs"
  mkdir -p "$log_directory_path"
  # remove existing preserved bootstrap logs
  rm -f "$log_directory_path"/bootstrap-*.log 2>/dev/null
  # reset standard logs
  : > "$log_directory_path/bootstrap.log"
}
