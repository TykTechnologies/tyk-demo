#!/bin/bash

organisation_id=$(cat .organisation-id)
dashboard_user_api_credentials=$(cat .dashboard-user-api-credentials)
tyk-sync sync -d http://localhost:3000 -s $dashboard_user_api_credentials -o $organisation_id -p tyk-sync-data