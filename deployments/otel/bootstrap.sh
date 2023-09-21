#!/bin/bash

source scripts/common.sh
deployment="Open Telemetry"
log_start_deployment
bootstrap_progress

jaeger_dash_url="http://localhost:16686"
jaeger_health_url="http://localhost:14269"

log_message "Waiting for Jaeger to respond ok"
wait_for_response "$jaeger_health_url" "200"
bootstrap_progress

otc_health_url="http://localhost:13133"
wait_for_response "$otc_health_url" "200"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ OTel
  ▽ Jaeger
                    URL : $jaeger_dash_url"