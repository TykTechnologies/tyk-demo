#!/bin/bash

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
  echo "$(date -u) $1" >> bootstrap.log
}

function log_start_deployment {
  log_message "START ▶ $deployment deployment bootstrap"
}

function log_end_deployment {
  log_message "END ▶ $deployment deployment bootstrap"
}

function recreate_all_tyk_containers {
  docker-compose -f deployments/tyk/docker-compose.yml -f deployments/tls/docker-compose.yml -p tyk-pro-docker-demo-extended --project-directory $(pwd) up --force-recreate -d --no-deps tyk-dashboard tyk-gateway tyk-pump
}