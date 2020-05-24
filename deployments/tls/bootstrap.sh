#!/bin/bash

source scripts/common.sh
deployment="TLS"
log_start_deployment
bootstrap_progress

gateway_tls_base_url="https://localhost:8081"

log_message "Waiting for gateway to respond ok"
wait_for_response "$gateway_tls_base_url/basic-open-api/get" "200"

log_end_deployment

echo -e "\033[2K     
▼ TLS 
  ▽ Gateway
               URL : $gateway_tls_base_url"