#!/bin/bash

source scripts/common.sh
deployment="Open Telemetry + New Relic"
log_start_deployment
bootstrap_progress

otc_health_url="http://localhost:13133"
wait_for_response "$otc_health_url" "200"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ OTel
  ▽ New Relic"