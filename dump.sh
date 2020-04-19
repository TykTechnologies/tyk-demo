#!/bin/bash

dashboard_user_api_credentials=$(cat .dashboard-user-api-credentials)
tyk-sync dump -d http://localhost:3000 -s $dashboard_user_api_credentials -t tyk-sync-data