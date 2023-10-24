#!/bin/bash
source scripts/common.sh

if ! grep -q "NEW_RELIC_LICENSE_KEY=" .env; then
  echo "ERROR: New Relic Licence Key missing from Docker environment file. Add your key to the NEW_RELIC_LICENSE_KEY variable in the .env file."
  exit 1
fi

deployment="Open Telemetry + New Relic"
log_start_deployment
bootstrap_progress

otc_health_url="http://localhost:13133"
wait_for_response "$otc_health_url" "200"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ OTel
  ▽ New Relic Dashboard
                    URL : https://one.newrelic.com
"