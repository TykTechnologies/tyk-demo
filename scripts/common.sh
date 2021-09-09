#!/bin/bash

# Contains functions useful for bootstrap scripts

# this array defines the hostnames that the bootstrap script will verify, and that the update-hosts script will use to modify /etc/hosts
declare -a tyk_demo_hostnames=("tyk-dashboard.localhost" "tyk-portal.localhost" "tyk-gateway.localhost" "tyk-gateway-2.localhost" "tyk-custom-domain.com" "tyk-worker-gateway.localhost" "acme-portal.localhost" "go-bench-suite.localhost")

spinner_chars="/-\|"
spinner_count=1

function bootstrap_progress {
  printf "  Bootstrapping $deployment ${spinner_chars:spinner_count++%${#spinner_chars}:1} \r"
}

function log_http_result {
  if [ "$1" = "200" ] || [ "$1" = "201" ]
  then 
    log_ok
  else 
    log_message "  ERROR: $1"
    exit 1
  fi
}

function log_json_result {
  status=$(echo $1 | jq -r '.Status')
  if [ "$status" = "OK" ] || [ "$status" = "Ok" ]
  then
    log_ok
  else
    log_message "  ERROR: $(echo $1 | jq -r '.Message')"
    exit 1
  fi
}

function log_ok {
  log_message "  Ok"
}

function log_message {
  echo "$(date -u) $1" >> bootstrap.log
}

function log_start_deployment {
  log_message "START ▶ $deployment deployment bootstrap"
}

function log_end_deployment {
  log_message "END ▶ $deployment deployment bootstrap"
}

function set_docker_environment_value {
  setting_current_value=$(grep "$1" .env)
  setting_desired_value="$1=$2"
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

function wait_for_response {
  url="$1"
  status=""
  desired_status="$2"
  header="$3"
  attempt_max="$4"
  attempt_count=0
  http_method="GET"

  if [ "$5" != "" ]
  then
    http_method="$5"
  fi

  log_message "  Expecting $2 response from $1"

  while [ "$status" != "$desired_status" ]
  do
    attempt_count=$((attempt_count+1))

    # header can be provided if auth is needed
    if [ "$header" != "" ]
    then
      status=$(curl -k -I -s -m5 $url -H "$header" 2>> bootstrap.log | head -n 1 | cut -d$' ' -f2)
    else
      status=$(curl -k -I -s -m5 -X $http_method $url 2>> bootstrap.log | head -n 1 | cut -d$' ' -f2)
    fi

    if [ "$status" == "$desired_status" ]
    then
      log_message "    Attempt $attempt_count succeeded, received '$status'"
      return 0
    else
      if [ "$attempt_max" != "" ]
      then
        log_message "    Attempt $attempt_count of $attempt_max unsuccessful, received '$status'"
      else
        log_message "    Attempt $attempt_count unsuccessful, received '$status'"
      fi

      # if max attempts reached, then exit with non-zero result
      if [ "$attempt_count" = "$attempt_max" ]
      then
        log_message "    Maximum retry count reached. Aborting."
        return 1
      fi

      sleep 2
    fi
  done
}

function hot_reload {
  gateway_host="$1"
  gateway_secret="$2"
  group="$3"
  result=""

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

set_context_data() {
  echo $5 > .context-data/$1-$2-$3-$4
}

get_context_data() {
  echo $(cat .context-data/$1-$2-$3-$4)
}

check_licence_expiry() {
  # read licence line from .env file
  licence_line=$(grep "$1=" .env)
  # extract licence JWT
  encoded_licence_jwt=$(echo $licence_line | sed -E 's/^[A-Z_]+=(.+)$/\1/')
  # decode licence payload
  decoded_licence_payload=$(decode_jwt $encoded_licence_jwt)
  # read licence expiry
  licence_expiry=$(echo $decoded_licence_payload | jq -r '.exp')   
  
  # get timestamp for now, to compare licence expiry against
  now=$(date '+%s') 
  # calculate the number of seconds remaining for the licence
  licence_seconds_remaining=$(expr $licence_expiry - $now)
  # calculate the number of days remaining for the licence (this sets a global variable, allowing the value to be used elsewhere)
  licence_days_remaining=$(expr $licence_seconds_remaining / 86400)
  if [[ "$licence_days_remaining" -le "7" ]]; then
    log_message "  WARNING: Licence $1 only has $licence_days_remaining days remaining"
  else
    log_message "  Licence $1 has $licence_days_remaining days remaining"
  fi

  # check if licence time remaining (in seconds) is less or equal to 0
  if [[ "$licence_seconds_remaining" -le "0" ]]; then
    return 1; # does not meet requirements
  else
    return 0; # does meet requirements
  fi
}

_decode_base64_url() {
  local len=$((${#1} % 4))
  local result="$1"
  if [ $len -eq 2 ]; then result="$1"'=='
  elif [ $len -eq 3 ]; then result="$1"'=' 
  fi
  echo "$result" | tr '_-' '/+' | base64 -d
}

decode_jwt() { _decode_base64_url $(echo -n $1 | cut -d "." -f ${2:-2}) | jq .; }

build_go_plugin() {
  go_plugin_filename=$1
  # each plugin must be in its own directory
  go_plugin_directory="$PWD/deployments/tyk/volumes/tyk-gateway/plugins/go/$2"
  go_plugin_build_version_filename=".bootstrap/go-plugin-build-version-$go_plugin_filename"
  go_plugin_build_version=$(cat $go_plugin_build_version_filename)
  go_plugin_path="$go_plugin_directory/$go_plugin_filename"
  log_message "Building Go Plugin $go_plugin_path using tag $gateway_image_tag"
  # only build the plugin if the currently built version is different to the Gateway version or the plugin shared object file does not exist
  if [ "$go_plugin_build_version" != "$gateway_image_tag" ] || [ ! -f $go_plugin_path ]; then
    docker run --rm -v $go_plugin_directory:/plugin-source tykio/tyk-plugin-compiler:$gateway_image_tag $go_plugin_filename
    plugin_container_exit_code="$?"
    if [[ "$plugin_container_exit_code" -ne "0" ]]; then
      log_message "  ERROR: Tyk Plugin Compiler container returned error code: $plugin_container_exit_code"
      exit 1
    fi
    echo $gateway_image_tag > $go_plugin_build_version_filename
    log_ok
  else
    # if you want to force a recompile of the plugin .so file, delete the .bootstrap/go-plugin-build-version file, or run the docker command manually
    log_message "  $go_plugin_filename has already built for $gateway_image_tag, skipping"
  fi
}

create_organisation() {
  local organisation_data_path="$1"
  local api_key="$2"
  local data_group="$3"
  local index="$4"
  local organisation_id=$(jq -r '.id' $organisation_data_path)
  local organisation_name=$(jq -r '.owner_name' $organisation_data_path)
  local portal_hostname=$(jq -r '.cname' $organisation_data_path)

  # create organisation in Tyk Dashboard database
  log_message "  Creating Organisation: $organisation_name"
  local api_response=$(curl $dashboard_base_url/admin/organisations/import -s \
    -H "admin-auth: $api_key" \
    -d @$organisation_data_path 2>> bootstrap.log)

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

create_dashboard_user() {
  local dashboard_user_data_path="$1"
  local api_key="$2"
  local data_group="$3"
  local index="$4"
  local dashboard_user_password=$(jq -r '.password' $dashboard_user_data_path)
  
  # create user in Tyk Dashboard database
  log_message "  Creating Dashboard User: $(jq -r '.email_address' $dashboard_user_data_path)"
  local api_response=$(curl $dashboard_base_url/admin/users -s \
    -H "admin-auth: $api_key" \
    -d @$dashboard_user_data_path 2>> bootstrap.log)

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
  # dashboard_user_emails+=("$dashboard_user_email")
  # dashboard_user_passwords+=("$dashboard_user_password")
  # dashboard_user_api_keys+=("$dashboard_user_api_key")
  # local dashboard_user_count=${#dashboard_user_emails[@]}
  set_context_data "$data_group" "dashboard-user" "$index" "email" "$dashboard_user_email"
  set_context_data "$data_group" "dashboard-user" "$index" "password" "$dashboard_user_password"
  set_context_data "$data_group" "dashboard-user" "$index" "api-key" "$dashboard_user_api_key"
  # echo "$dashboard_user_api_key" > ".context-data/dashboard-user-$dashboard_user_count-api-key"

  # reset the password
  log_message "  Resetting password for $dashboard_user_email"
  api_response=$(curl $dashboard_base_url/api/users/$dashboard_user_id/actions/reset -s \
    -H "authorization: $dashboard_user_api_key" \
    --data-raw '{
        "new_password":"'$dashboard_user_password'",
        "user_permissions": { "IsAdmin": "admin" }
      }' 2>> bootstrap.log)

  log_json_result "$api_response"

  log_message "    Password: $dashboard_user_password"
}

create_user_group() {
  local user_group_data_path="$1"
  local api_key="$2"
  local data_group="$3"
  local index="$4"
  local user_group_name=$(jq -r '.name' $user_group_data_path)

  # create user group in Tyk Dashboard database
  log_message "  Creating User Group: $user_group_name"
  local api_response=$(curl $dashboard_base_url/api/usergroups -s \
    -H "Authorization: $api_key" \
    -d @$user_group_data_path 2>> bootstrap.log)

  # validate result
  log_json_result "$api_response"
  
  # extract data from response
  local user_group_id=$(echo "$api_response" | jq -r '.Meta')

  set_context_data "$data_group" "dashboard-user-group" "$index" "id" "$user_group_id"

  log_message "    Id: $user_group_id"
}

create_webhook() {
  local webhook_data_path="$1"
  local api_key="$2"
  local webhook_name=$(jq -r '.name' $webhook_data_path)

  # create webhook in Tyk Dashboard database
  log_message "  Creating Webhook: $webhook_name"
  local api_response=$(curl $dashboard_base_url/api/hooks -s \
    -H "Authorization: $api_key" \
    -d @$webhook_data_path 2>> bootstrap.log)

  # validate result
  log_json_result "$api_response"
}



initialise_portal() {
  local organisation_id="$1"
  local api_key="$2"

  log_message "  Creating default settings"
  local api_response=$(curl $dashboard_base_url/api/portal/configuration -s \
    -H "Authorization: $api_key" \
    -d "{}" 2>> bootstrap.log)
  log_json_result "$api_response"

  log_message "  Initialising Catalogue"
  api_response=$(curl $dashboard_base_url/api/portal/catalogue -s \
    -H "Authorization: $api_key" \
    -d '{"org_id": "'$organisation_id'"}' 2>> bootstrap.log)
  log_json_result "$api_response"
  
  catalogue_id=$(echo "$api_response" | jq -r '.Message')
  log_message "    Id: $catalogue_id"
}

create_portal_page() {
  local page_data_path="$1"
  local api_key="$2"
  local page_title=$(jq -r '.title' $page_data_path)

  log_message "  Creating Page: $page_title"

  log_json_result "$(curl $dashboard_base_url/api/portal/pages -s \
    -H "Authorization: $api_key" \
    -d @$page_data_path 2>> bootstrap.log)"
}

create_portal_developer() {
  local developer_data_path="$1"
  local api_key="$2"
  local index="$3"
  local developer_email=$(jq -r '.email' $developer_data_path)
  local developer_password=$(jq -r '.password' $developer_data_path)
  log_message "  Creating Developer: $developer_email"

  local api_response=$(curl $dashboard_base_url/api/portal/developers -s \
    -H "Authorization: $api_key" \
    -d @$developer_data_path 2>> bootstrap.log)
  log_json_result "$api_response"

  set_context_data "$data_group" "portal-developer" "$index" "email" "$developer_email"
  set_context_data "$data_group" "portal-developer" "$index" "password" "$developer_password"

  log_message "    Password: $developer_password"
}

create_portal_documentation() {
  local documentation_data_path="$1"
  local api_key="$2"
  local documentation_title=$(jq -r '.info.title' $documentation_data_path)
  log_message "  Creating Documentation: $documentation_title"

  # replace with sed or jq?
  echo -n '{
            "api_id":"",
            "doc_type":"swagger",
            "documentation":"' >/tmp/swagger_encoded.out
  cat $documentation_data_path | base64 >>/tmp/swagger_encoded.out
  echo '"}' >>/tmp/swagger_encoded.out

  local api_response=$(curl $dashboard_base_url/api/portal/documentation -s \
    -H "Authorization: $api_key" \
    -d "@/tmp/swagger_encoded.out" \
      2>> bootstrap.log)

  log_json_result "$api_response"

  rm /tmp/swagger_encoded.out

  local documentation_id=$(echo "$api_response" | jq -r '.Message')

  log_message "    Id: $documentation_id"

  echo "$documentation_id"
}

create_portal_catalogue() {
  local catalogue_data_path="$1"
  local api_key="$2"
  local documentation_id="$3"
  local catalogue_name=$(jq -r '.name' $catalogue_data_path)

  log_message "  Adding Catalogue Entry: $catalogue_name"

  # get the existing catalogue
  catalogue="$(curl $dashboard_base_url/api/portal/catalogue -s \
    -H "Authorization: $api_key" 2>> bootstrap.log)"

  # add documentation id to new catalogue
  new_catalogue=$(jq --arg documentation_id "$documentation_id" '.documentation = $documentation_id' $catalogue_data_path)

  # update the catalogue with the new catalogue entry
  updated_catalogue=$(jq --argjson new_catalogue "[$new_catalogue]" '.apis += $new_catalogue' <<< "$catalogue")

  log_json_result "$(curl $dashboard_base_url/api/portal/catalogue -X 'PUT' -s \
    -H "Authorization: $api_key" \
    -d "$updated_catalogue" 2>> bootstrap.log)"
}

create_api() {
  local api_data_path="$1"
  local api_key="$2"
  local api_name=$(jq -r '.api_definition.name' $api_data_path)

  log_message "  Creating API: $api_name"

  request_payload=$(jq --slurpfile new_api "$api_data_path" '.apis += $new_api' deployments/tyk/data/tyk-dashboard/admin-api-apis-import-template.json)

  # TODO: fix webhook id reference

  api_response="$(curl $dashboard_base_url/admin/apis/import -s \
    -H "admin-auth: $api_key" \
    -d "$request_payload" 2>> bootstrap.log)"

  log_json_result "$api_response"

  api_id=$(echo $api_response | jq -r '.Meta | keys[]')

  log_message "    Id: $api_id"
}

create_policy() {
  local policy_data_path="$1"
  local api_key="$2"
  local policy_name=$(jq -r '.name' $policy_data_path)

  log_message "  Creating Policy: $policy_name"

  request_payload=$(jq --slurpfile new_policy "$policy_data_path" '.Data += $new_policy' deployments/tyk/data/tyk-dashboard/admin-api-policies-import-template.json)

  api_response="$(curl $dashboard_base_url/admin/policies/import -s \
    -H "admin-auth: $api_key" \
    -d "$request_payload" 2>> bootstrap.log)"

  log_json_result "$api_response"

  policy_id=$(echo $api_response | jq -r '.Meta | keys[]')

  log_message "    Id: $policy_id"
}
