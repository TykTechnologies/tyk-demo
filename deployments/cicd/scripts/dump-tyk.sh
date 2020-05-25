#!/bin/bash

dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)
docker run --rm \
  --network tyk-pro-docker-demo-extended_tyk \
  -v $(pwd)/deployments/cicd/data/gitea/tyk-data:/opt/tyk-sync/data \
  tykio/tyk-sync:v1.1.0 \
  dump -d http://tyk-dashboard:3000 -s $dashboard_user_api_credentials -t data