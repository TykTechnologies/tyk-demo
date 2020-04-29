#!/bin/bash

zipkin_base_url="http://localhost:9411/zipkin/"
zipkin_status=""
zipkin_status_desired="200"
zipkin_tries=0

while [ "$zipkin_status" != "$zipkin_status_desired" ]
do
  zipkin_tries=$((zipkin_tries+1))
  dot=$(printf "%-${zipkin_tries}s" ".")
  echo -ne "  Bootstrapping Zipkin ${dot// /.} \r"
  zipkin_status=$(curl -I -m2 $zipkin_base_url 2>/dev/null | head -n 1 | cut -d$' ' -f2)

  if [ "$zipkin_status" != "$zipkin_status_desired" ]
  then
    sleep 1
  fi
done

echo -e "\033[2K"

cat <<EOF   
            Zipkin
               URL : $zipkin_base_url
               
EOF