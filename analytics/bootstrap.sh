#!/bin/bash

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping Kibana ${dots// /.} \r"
}

kibana_base_url="http://localhost:5601"
kibana_status=""
kibana_status_desired="200"

# wait for kibana to return desired response
while [ "$kibana_status" != "$kibana_status_desired" ]
do
  kibana_status=$(curl -I -m2 $kibana_base_url/app/kibana 2>/dev/null | head -n 1 | cut -d$' ' -f2)  
  if [ "$kibana_status" != "$kibana_status_desired" ]
  then
    sleep 1
  fi
  bootstrap_progress
done

# add index pattern
curl $kibana_base_url/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2?overwrite=true -s \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @analytics/data/kibana/index-patterns/tyk-analytics.json > /dev/null
bootstrap_progress

# add visualisation
curl $kibana_base_url/api/saved_objects/visualization/407e91c0-8168-11ea-9323-293461ad91e5?overwrite=true -s \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @analytics/data/kibana/visualizations/request-count-by-time.json > /dev/null
bootstrap_progress

# stop the pump instance deployed by the base deployment, so it is replaced by the instance from this deployment
docker-compose stop tyk-pump 2> /dev/null
bootstrap_progress

# send a test request to provide Kibana with data, since request sent in base bootstrap process will not have been picked up by elasticsearch-enabled pump
curl -s localhost:8080/basic-open-api/get > /dev/null

echo -e "\033[2K            Kibana
               URL : $kibana_base_url
"