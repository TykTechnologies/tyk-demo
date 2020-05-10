#!/bin/bash

source scripts/common.sh
feature="Analytics"
log_start_feature
bootstrap_progress

kibana_base_url="http://localhost:5601"
kibana_status=""
kibana_status_desired="200"

echo "Waiting for kibana to return desired response" >> bootstrap.log
while [ "$kibana_status" != "$kibana_status_desired" ]
do
  kibana_status=$(curl -I -s -m5 $kibana_base_url/app/kibana 2>> bootstrap.log | head -n 1 | cut -d$' ' -f2)  
  if [ "$kibana_status" != "$kibana_status_desired" ]
  then
    echo "  Request unsuccessful, retrying..." >> bootstrap.log
    sleep 2
  else
    echo "  Ok" >> bootstrap.log
  fi
  bootstrap_progress
done

echo "Adding index pattern" >> bootstrap.log
result=$(curl $kibana_base_url/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2?overwrite=true -s -o /dev/null -w "%{http_code}" \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @analytics/data/kibana/index-patterns/tyk-analytics.json 2>> bootstrap.log)
log_http_result $result
bootstrap_progress

echo "Adding visualisation" >> bootstrap.log
result=$(curl $kibana_base_url/api/saved_objects/visualization/407e91c0-8168-11ea-9323-293461ad91e5?overwrite=true -s -o /dev/null -w "%{http_code}" \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @analytics/data/kibana/visualizations/request-count-by-time.json 2>> bootstrap.log)
log_http_result $result
bootstrap_progress

echo "Stopping the pump instance deployed by the base deployment" >> bootstrap.log
# so it is replaced by the instance from this deployment
docker-compose stop tyk-pump 2>/dev/null
echo "  Ok" >> bootstrap.log
bootstrap_progress

echo "Sending a test request to provide Kibana with data" >> bootstrap.log
# since request sent in base bootstrap process will not have been picked up by elasticsearch-enabled pump
result=$(curl -s localhost:8080/basic-open-api/get -o /dev/null -w "%{http_code}" 2>> bootstrap.log)
log_http_result $result

log_end_feature

echo -e "\033[2K
▼ Analytics
  ▽ Kibana
               URL : $kibana_base_url"