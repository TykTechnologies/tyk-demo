#!/bin/bash

# uses Tyk Sync to extract API and Policy data
dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)
tyk_data_repo_path=$(cat .context-data/tyk-data-repo-path)
docker run --rm \
  --network tyk-pro-docker-demo-extended_tyk \
  -v $tyk_data_repo_path:/opt/tyk-sync/data \
  tykio/tyk-sync:v1.1.0 \
  dump -d http://tyk-dashboard:3000 -s $dashboard_user_api_credentials -t data