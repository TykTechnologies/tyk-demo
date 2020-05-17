#!/bin/bash

source scripts/common.sh
deployment="Instrumentation"
log_start_deployment
bootstrap_progress

log_message "Sending API call to generate Instrumentation data"
gateway_status=""
while [ "$gateway_status" != "200" ]
do
  gateway_status=$(curl -I -s http://localhost:8080/basic-open-api/get 2>> bootstrap.log | head -n 1 | cut -d$' ' -f2)
  if [ "$gateway_status" != "200" ]
  then
    log_message "  Request unsuccessful, retrying..."
    sleep 2
  else
    log_ok
  fi
  bootstrap_progress
done

log_end_deployment

echo -e "\033[2K          
▼ Instrumentation
  ▽ Graphite
               URL : http://localhost:8060"