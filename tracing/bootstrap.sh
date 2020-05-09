#!/bin/bash

echo "Begin tracing bootstrap" >>bootstrap.log

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping Zipkin ${dots// /.} \r"
}

zipkin_base_url="http://localhost:9411/zipkin/"
zipkin_status=""
zipkin_status_desired="200"

echo "Wait for zipkin to respond ok" >>bootstrap.log
while [ "$zipkin_status" != "$zipkin_status_desired" ]
do
  zipkin_status=$(curl -I -s -m5 $zipkin_base_url 2>>bootstrap.log | head -n 1 | cut -d$' ' -f2)
  if [ "$zipkin_status" != "$zipkin_status_desired" ]
  then
    echo "Zipkin status:$zipkin_status" >>bootstrap.log
    sleep 1
  fi
  bootstrap_progress
done

echo "Check tracing env var is set correctly" >>bootstrap.log
tracing_setting=$(grep "TRACING_ENABLED" .env)
tracing_setting_desired="TRACING_ENABLED=true"

if [[ $tracing_setting != $tracing_setting_desired ]]
then
     # if missing
     if [ ${#tracing_setting} == 0 ]
     then
          echo "Add tracing docker env var" >>bootstrap.log
          echo $tracing_setting_desired >> .env
     else
          echo "Replace tracing docker env var" >>bootstrap.log
          sed -i.bak 's/'"$tracing_setting"'/'"$tracing_setting_desired"'/g' ./.env
          rm .env.bak
     fi
     bootstrap_progress
     
     echo "Restart Tyk containers to take effect" >>bootstrap.log
     docker-compose restart 2>/dev/null
     bootstrap_progress
fi

echo "End tracing bootstrap" >>bootstrap.log

echo -e "\033[2K
▶ Tracing

  ▷ Zipkin
               URL : $zipkin_base_url
"