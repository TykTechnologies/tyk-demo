#!/bin/bash

source scripts/common.sh
deployment="Instrumentation"
log_start_deployment
bootstrap_progress

log_message "Sending API call to generate Instrumentation data"
wait_for_response "http://localhost:8080/basic-open-api/get" "200"

log_end_deployment

echo -e "\033[2K          
▼ Instrumentation
  ▽ Graphite
               URL : http://localhost:8060"