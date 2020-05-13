#!/bin/bash

source scripts/common.sh
deployment="Instrumentation"
log_start_deployment
bootstrap_progress

log_message "Checking instrumentation env var is set correctly"
instrumentation_setting=$(grep "INSTRUMENTATION_ENABLED" .env)
instrumentation_setting_desired="INSTRUMENTATION_ENABLED=1"
if [[ $instrumentation_setting != $instrumentation_setting_desired ]]
then
  # if missing
  if [ ${#instrumentation_setting} == 0 ]
  then
     log_message "  Adding instrumentation setting to docker env var file"
     echo $instrumentation_setting_desired >> .env
  else
     log_message "  Setting instrumentation docker env var to 1"
     sed -i.bak 's/'"$instrumentation_setting"'/'"$instrumentation_setting_desired"'/g' ./.env
     rm .env.bak
  fi
  bootstrap_progress
  log_message "  Recreating Tyk containers to take effect"
  recreate_all_tyk_containers
  bootstrap_progress
fi
log_ok

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