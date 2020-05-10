#!/bin/bash

echo "Begin analytics bootstrap" >>bootstrap.log

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping Kibana ${dots// /.} \r"
}

kibana_base_url="http://localhost:5601"
kibana_status=""
kibana_status_desired="200"

echo "Wait for kibana to return desired response" >>bootstrap.log
while [ "$kibana_status" != "$kibana_status_desired" ]
do
  kibana_status=$(curl -I -s -m5 $kibana_base_url/app/kibana 2>>bootstrap.log | head -n 1 | cut -d$' ' -f2)  
  if [ "$kibana_status" != "$kibana_status_desired" ]
  then
    echo "Kibana status:$kibana_status" >>bootstrap.log
    sleep 1
  fi
  bootstrap_progress
done

echo "Add index pattern" >>bootstrap.log
curl $kibana_base_url/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2?overwrite=true -s -o /dev/null \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @analytics/data/kibana/index-patterns/tyk-analytics.json 2>>bootstrap.log
bootstrap_progress

echo "Add visualisation" >>bootstrap.log
curl $kibana_base_url/api/saved_objects/visualization/407e91c0-8168-11ea-9323-293461ad91e5?overwrite=true -s -o /dev/null \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @analytics/data/kibana/visualizations/request-count-by-time.json 2>>bootstrap.log
bootstrap_progress

echo "Stop the pump instance deployed by the base deployment" >>bootstrap.log
# so it is replaced by the instance from this deployment
docker-compose stop tyk-pump 2>/dev/null
bootstrap_progress

echo "Send a test request to provide Kibana with data" >>bootstrap.log
# since request sent in base bootstrap process will not have been picked up by elasticsearch-enabled pump
curl -s localhost:8080/basic-open-api/get -o /dev/null 2>>bootstrap.log

echo "End analytics bootstrap" >>bootstrap.log

echo -e "\033[2K
▼ Analytics

  ▽ Kibana
               URL : $kibana_base_url
"