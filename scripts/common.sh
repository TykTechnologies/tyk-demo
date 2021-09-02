#!/bin/bash

# Contains functions useful for bootstrap scripts

# this array defines the hostnames that the bootstrap script will verify, and that the update-hosts script will use to modify /etc/hosts
declare -a tyk_demo_hostnames=("tyk-dashboard.localhost" "tyk-portal.localhost" "tyk-gateway.localhost" "tyk-gateway-2.localhost" "tyk-custom-domain.com" "tyk-worker-gateway.localhost" "acme-portal.localhost")

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping $deployment ${dots// /.} \r"
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
