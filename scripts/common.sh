#!/bin/bash

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping $feature ${dots// /.} \r"
}

function log_http_result {
  if [ "$1" = "200" ] || [ "$1" = "201" ]
  then 
    log_ok
  else 
    log_message "  Error"
  fi
}

function log_json_result {
  status=$(echo $1 | jq -r '.Status')
  if [ "$status" = "OK" ] || [ "$status"= "Ok" ]
  then
    log_ok
  else
    log_message "  Error"
  fi
}

function log_ok {
  log_message "  Ok"
}

function log_message {
  echo "$1" >> bootstrap.log
}

function log_start_feature {
  log_message "▶ START $feature bootstrap"
}

function log_end_feature {
  log_message "▶ END $feature bootstrap"
}