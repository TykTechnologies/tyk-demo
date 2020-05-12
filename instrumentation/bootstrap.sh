#!/bin/bash

source scripts/common.sh
feature="Instrumentation"
log_start_feature
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
  docker-compose -f tyk/docker-compose.yml -p tyk-pro-docker-demo-extended up --force-recreate --no-deps -d tyk-dashboard tyk-gateway tyk-pump
  bootstrap_progress
fi
log_ok

log_end_feature

echo -e "\033[2K          
▼ Instrumentation
  ▽ Graphite
               URL : http://localhost:8060"