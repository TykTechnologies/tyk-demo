#!/bin/bash

source scripts/common.sh
deployment="Tracing"
log_start_deployment
bootstrap_progress

zipkin_base_url="http://localhost:9411/zipkin/"

log_message "Waiting for Zipkin to respond ok"
zipkin_status=""
zipkin_status_desired="200"
while [ "$zipkin_status" != "$zipkin_status_desired" ]
do
  zipkin_status=$(curl -I -s -m5 $zipkin_base_url 2>> bootstrap.log | head -n 1 | cut -d$' ' -f2)
  if [ "$zipkin_status" != "$zipkin_status_desired" ]
  then
    log_message "  Request unsuccessful, retrying..."
    sleep 2
  else
    log_ok
  fi
done
bootstrap_progress

log_message "Checking tracing env var is set correctly"
tracing_setting=$(grep "TRACING_ENABLED" .env)
tracing_setting_desired="TRACING_ENABLED=true"
if [[ $tracing_setting != $tracing_setting_desired ]]
then
  # if tracing setting is missing from the config
  if [ ${#tracing_setting} == 0 ]
  then
      log_message "  Adding tracing docker environment variable to .env file"
      echo $tracing_setting_desired >> .env
  else
      log_message "  Setting tracing docker envionment variable to true"
      sed -i.bak 's/'"$tracing_setting"'/'"$tracing_setting_desired"'/g' ./.env
      rm .env.bak
  fi
  bootstrap_progress

  log_message "  Recreating Tyk containers to take effect"
  recreate_all_tyk_containers
fi
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Tracing
  ▽ Zipkin
               URL : $zipkin_base_url"