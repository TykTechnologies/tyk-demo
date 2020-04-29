#!/bin/bash

kibana_base_url="http://localhost:5601"
kibana_status=""
kibana_status_desired="200"
kibana_tries=0

while [ "$kibana_status" != "$kibana_status_desired" ]
do
  kibana_tries=$((kibana_tries+1))
  dot=$(printf "%-${kibana_tries}s" ".")
  echo -ne "  Bootstrapping Kibana ${dot// /.} \r"
  kibana_status=$(curl -I -m2 $kibana_base_url/app/kibana 2>/dev/null | head -n 1 | cut -d$' ' -f2)
  
  if [ "$kibana_status" != "$kibana_status_desired" ]
  then
    sleep 1
  fi
done

curl $kibana_base_url/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2?overwrite=true -s \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @bootstrap-data/kibana/index-patterns/tyk-analytics.json > /dev/null
curl $kibana_base_url/api/saved_objects/visualization/407e91c0-8168-11ea-9323-293461ad91e5?overwrite=true -s \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @bootstrap-data/kibana/visualizations/request-count-by-time.json > /dev/null

echo -e "\033[2K"

cat <<EOF
            Kibana
               URL : $kibana_base_url
               
EOF