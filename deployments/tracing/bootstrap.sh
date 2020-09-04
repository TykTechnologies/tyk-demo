#!/bin/bash

source scripts/common.sh
deployment="Tracing"
log_start_deployment
bootstrap_progress

zipkin_base_url="http://localhost:9411/zipkin/"

log_message "Waiting for Zipkin to respond ok"
wait_for_response "$zipkin_base_url" "200"

log_end_deployment

echo -e "\033[2K
▼ Tracing
  ▽ Zipkin
                    URL : $zipkin_base_url"