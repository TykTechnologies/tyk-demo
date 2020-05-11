#!/bin/bash

source scripts/common.sh
feature="Tracing"
log_start_feature
bootstrap_progress

zipkin_base_url="http://localhost:9411/zipkin/"
zipkin_status=""
zipkin_status_desired="200"

log_message "Waiting for Zipkin to respond ok"
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
  bootstrap_progress
done

log_message "Checking tracing env var is set correctly"
tracing_setting=$(grep "TRACING_ENABLED" .env)
tracing_setting_desired="TRACING_ENABLED=true"
if [[ $tracing_setting != $tracing_setting_desired ]]
then
  # if missing
  if [ ${#tracing_setting} == 0 ]
  then
      log_message "  Adding tracing docker environment variable to .env file"
      echo $tracing_setting_desired >> .env
  else
      log_message "  Setting tracing docker envionment variable to desired value"
      sed -i.bak 's/'"$tracing_setting"'/'"$tracing_setting_desired"'/g' ./.env
      rm .env.bak
  fi
  bootstrap_progress

  log_message "  Restarting Tyk containers to take effect"
  docker-compose restart 2> /dev/null
  bootstrap_progress
else
  log_ok
fi

log_end_feature

echo -e "\033[2K
▼ Tracing
  ▽ Zipkin
               URL : $zipkin_base_url"