#!/bin/bash

source scripts/common.sh
deployment="TLS"
log_start_deployment
bootstrap_progress

gateway_tls_base_url="https://localhost:8081"

log_message "Waiting for gateway to respond ok"
gateway_status=""
gateway_status_desired="200"
gateway_tries=0
while [ "$gateway_status" != "$gateway_status_desired" ]
do
  gateway_status=$(curl -I -s -k -m2 $gateway_tls_base_url/basic-open-api/get 2>> bootstrap.log | head -n 1 | cut -d$' ' -f2)
  if [ "$gateway_status" != "$gateway_status_desired" ]
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
▼ TLS 
  ▽ Gateway
               URL : $gateway_tls_base_url"