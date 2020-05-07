#!/bin/bash

dot_count=""

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping Tyk ${dots// /.} \r"
}

zipkin_base_url="http://localhost:9411/zipkin/"
zipkin_status=""
zipkin_status_desired="200"

while [ "$zipkin_status" != "$zipkin_status_desired" ]
do
  zipkin_status=$(curl -I -m2 $zipkin_base_url 2>/dev/null | head -n 1 | cut -d$' ' -f2)
  if [ "$zipkin_status" != "$zipkin_status_desired" ]
  then
    sleep 1
  fi
  bootstrap_progress
done

# check tracing env var is set correctly
tracing_setting=$(grep "TRACING_ENABLED" .env)
tracing_setting_desired="TRACING_ENABLED=true"

if [[ $tracing_setting != $tracing_setting_desired ]]
then
     # if missing
     if [ ${#tracing_setting} == 0 ]
     then
          # then add
          echo $tracing_setting_desired >> .env
     else
          # else replace (done this way to be compatible across different linux versions)
          sed -i.bak 's/'"$tracing_setting"'/'"$tracing_setting_desired"'/g' ./.env
          rm .env.bak
     fi
     bootstrap_progress
     
     # restart tyk containers to take effect
     docker-compose restart 2> /dev/null
     bootstrap_progress
fi


echo -e "\033[2K            Zipkin
               URL : $zipkin_base_url
"