#!/bin/bash

echo "Begin tls bootstrap" >>bootstrap.log

gateway_tls_base_url="https://localhost:8081"
gateway_status=""
gateway_status_desired="200"
gateway_tries=0

echo "Wait for gateway to respond ok" >>bootstrap.log
while [ "$gateway_status" != "$gateway_status_desired" ]
do
  gateway_tries=$((gateway_tries+1))
  dot=$(printf "%-${gateway_tries}s" ".")
  echo -ne "  Bootstrapping Gateway (TLS) ${dot// /.} \r"
  gateway_status=$(curl -I -k -m2 $gateway_tls_base_url/basic-open-api/get 2>>bootstrap.log | head -n 1 | cut -d$' ' -f2)

  if [ "$gateway_status" != "$gateway_status_desired" ]
  then
    echo "Gateway status:$gateway_status" >>bootstrap.log
    sleep 1
  fi
done

echo "End tls bootstrap" >>bootstrap.log

echo -e "\033[2K            Gateway (TLS)
               URL : $gateway_tls_base_url
"