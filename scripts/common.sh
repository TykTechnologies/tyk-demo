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

  log_message "  Expecting $2 response from $1"

  while [ "$status" != "$desired_status" ]
  do
    attempt_count=$((attempt_count+1))

    # header can be provided if auth is needed
    if [ "$header" != "" ]
    then
      status=$(curl -k -I -s -m5 $url -H "$header" 2>> bootstrap.log | head -n 1 | cut -d$' ' -f2)
    else
      status=$(curl -k -I -s -m5 $url 2>> bootstrap.log | head -n 1 | cut -d$' ' -f2)
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

function check_licence_expiry {
  # read licence line from .env file
  licence_line=$(grep "$1=" .env)
  # extract the part containing the base64 encoded payload
  licence_payload_encoded=$(echo $licence_line | sed -E 's/^[^\.]+\.([^\.]+)\.[^\.]+$/\1/')
  # decode the payload
  licence_payload_decoded=$(echo $licence_payload_encoded | base64 -d)
  # closing bracket needs to be added as it gets cut off from original value due to no new line character at end of the decoded string (I think... I probably did something wrong, but it seems to work ok)
  licence_payload_decoded_fixed="$licence_payload_decoded}" 
  # now we can read the licence expiry (as unix time)
  licence_expiry=$(echo $licence_payload_decoded_fixed | jq -r '.exp') 
  
  # get timestamp for now, to compare against licence expiry against
  now=$(date '+%s') 
  # calculate the number of seconds remaining for the licence
  licence_seconds_remaining=$(expr $licence_expiry - $now)
  # calculate the number of days remaining for the licence (this sets a global variable, allowing the value to be used elsewhere)
  licence_days_remaining=$(expr $licence_seconds_remaining / 86400)
  # this variable is used to check whether the licence has got at least this number of seconds remaining
  minimum_licence_seconds_required=$2

  # if a time limit is not provided
  if [[ "$minimum_licence_seconds_required" -eq "0" ]]; then
    # default time limit to 0, meaning that the function will return false only if the licence has expired
    minimum_licence_seconds_required=0
  fi

  # check if licence time remaining (in seconds) is less or equal to the time limit
  if [[ "$licence_seconds_remaining" -le "$minimum_licence_seconds_required" ]]; then
    return 1; # does not meet requirements
  else
    return 0; # meets requirements
  fi
}

function get_licence_remaining_time_from_env {
  # process scripted step by step for clarity
  licence_line=$(grep "$1=" .env)
  licence_payload_encoded=$(echo $licence_line | sed -E 's/^[^\.]+\.([^\.]+)\.[^\.]+$/\1/')
  licence_payload_decoded=$(echo $licence_payload_encoded | base64 -d)
  licence_payload_decoded_fixed="$licence_payload_decoded}" # closing bracket needs to be added as it gets cut off from original value due to no new line character at end of the decoded string (I think...)
  licence_expiry=$(echo $licence_payload_decoded_fixed | jq -r '.exp')
  now=$(date '+%s')
  licence_remaining=$(expr $licence_expiry - $now)

  # returns the number of seconds remaining
  echo "licrem:$licence_remaining"
  return $licence_remaining
}