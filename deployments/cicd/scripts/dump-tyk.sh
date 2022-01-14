#!/bin/bash

# uses Tyk Sync to extract API and Policy data from Tyk, and store it in the Gitea tyk-data repository directory

dashboard_user_api_credentials=$(cat .context-data/1-dashboard-user-1-api-key)
gitea_tyk_data_repo_path=$(cat .context-data/gitea-tyk-data-repo-path)
docker run --rm \
  --network tyk-demo_tyk \
  -v $gitea_tyk_data_repo_path:/opt/tyk-sync/data \
  tykio/tyk-sync:v1.1.0 \
  dump -d http://tyk-dashboard:3000 -s $dashboard_user_api_credentials -t data
