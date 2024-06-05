#!/bin/bash

source scripts/common.sh
deployment="Load Balancer"

log_start_deployment
bootstrap_progress

# log_message "Restart Gateways to load latest certificates"
# docker restart tyk-demo-tyk-gateway-3-1 tyk-demo-tyk-gateway-4-1 1>/dev/null 2>>logs/bootstrap.log
# if [ "$?" != 0 ]; then
#   echo "Error when restart Gateways to load latest certificates"
#   exit 1
# fi
# log_ok

log_message "Restart nginx to reset load balancer"
docker restart tyk-demo-nginx-1 1>/dev/null 2>>logs/bootstrap.log
if [ "$?" != 0 ]; then
  echo "Error when restarting nginx to reset load balancer"
  exit 1
fi
log_ok

log_end_deployment

echo -e "\033[2K
▼ Load Balancer
  ▽ Gateway 3 ($(get_service_image_tag "tyk-gateway-3"))
                    URL : access via load balancer
  ▽ Gateway 4 ($(get_service_image_tag "tyk-gateway-4"))
                    URL : access via load balancer
  ▽ Load Balancer
                   Host : http://localhost:8091
            Example URL : http://localhost:8091/lb3/basic-open-api/get"
