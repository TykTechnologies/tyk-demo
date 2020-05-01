#!/bin/bash

organisation_id=$(cat .context-data/organisation-id)
dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)
docker run --rm \
  --network tyk-pro-docker-demo-extended_tyk \
  -v $(pwd)/data/tyk-sync:/opt/tyk-sync/data \
  tykio/tyk-sync:v1.1.0 \
  sync -d http://tyk-dashboard:3000 -s $dashboard_user_api_credentials -p data