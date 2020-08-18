#!/bin/bash

source scripts/common.sh
deployment="Tracing-Jaeger"
log_start_deployment
bootstrap_progress

jaeger_base_url="http://localhost:16686/search"

log_message "Waiting for Zipkin to respond ok"
wait_for_response "$jaeger_base_url" "200"

log_end_deployment

echo -e "\033[2K
▼ Tracing
  ▽ Jaeger
               URL : $jaeger_base_url"