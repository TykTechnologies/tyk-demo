#!/bin/bash

source scripts/common.sh
feature="SSO"
log_start_feature
bootstrap_progress

dashboard_sso_base_url="http://localhost:3001"
identity_broker_base_url="http://localhost:3010"

echo "Creating Identity Broker Profiles" >> bootstrap.log
organisation_id=$(cat .context-data/organisation-id)
dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)
user_group_default_id=$(cat .context-data/user_group_default_id)
user_group_readonly_id=$(cat .context-data/user_group_readonly_id)
user_group_admin_id=$(cat .context-data/user_group_admin_id)
identity_broker_api_credentials=$(cat sso/volumes/tyk-identity-broker/tib.conf | jq -r .Secret)
identity_broker_profile_tyk_dashboard_data=$(cat sso/data/tyk-identity-broker/profile-tyk-dashboard.json | \
  sed 's/ORGANISATION_ID/'"$organisation_id"'/' | \
  sed 's/DASHBOARD_USER_API_CREDENTIALS/'"$dashboard_user_api_credentials"'/' | \
  sed 's/DASHBOARD_USER_GROUP_DEFAULT/'"$user_group_default_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_READONLY/'"$user_group_readonly_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_ADMIN/'"$user_group_admin_id"'/')
result=$(curl $identity_broker_base_url/api/profiles/tyk-dashboard -s -w "%{http_code}" -o /dev/null \
  -H "Authorization: $identity_broker_api_credentials" \
  -d "$(echo $identity_broker_profile_tyk_dashboard_data)" 2>> bootstrap.log)
log_http_result $result

log_end_feature

echo -e "\033[2K
▼ SSO
  ▽ Dashboard
               URL : $dashboard_sso_base_url
    ▿ Admin user
          Username : dashboard.admin@example.org
          Password : Abcd1234
    ▿ Read-only user
          Username : dashboard.readonly@example.org
          Password : Abcd1234
    ▿ Default user
          Username : dashboard.default@example.org
          Password : Abcd1234
  ▽ Identity Broker
       Profile URL : $identity_broker_base_url/auth/tyk-dashboard/openid-connect"