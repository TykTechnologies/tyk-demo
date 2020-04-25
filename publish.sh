#!/bin/bash

dashboard_user_api_credentials=$(cat .dashboard-user-api-credentials)
docker run --rm \
  --network tyk-pro-docker-demo-extended_tyk \
  -v $(pwd)/data/tyk-sync:/opt/tyk-sync/data \
  tykio/tyk-sync:v1.1.0 \
  publish -d http://tyk-dashboard:3000 -s $dashboard_user_api_credentials -p data