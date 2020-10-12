#!/bin/bash

source scripts/common.sh
deployment="SSO"
log_start_deployment
bootstrap_progress

dashboard_sso_base_url="http://localhost:3001"
identity_broker_base_url="http://localhost:3010"

log_message "Getting config data"
identity_broker_api_credentials=$(cat deployments/sso/volumes/tyk-identity-broker/tib.conf | jq -r .Secret)
log_message "  TIB base URL: $identity_broker_base_url"
log_message "  TIB API Credentials: $identity_broker_api_credentials"
log_ok
bootstrap_progress

log_message "Creating empty profiles.json"
docker exec tyk-demo_tyk-identity-broker_1 sh -c "touch /opt/tyk-identity-broker/profiles.json"

log_message "Generating Profile data"
organisation_id=$(cat .context-data/organisation-id)
dashboard_user_api_credentials=$(cat .context-data/dashboard-user-api-credentials)
user_group_default_id=$(cat .context-data/user-group-default-id)
user_group_readonly_id=$(cat .context-data/user-group-readonly-id)
user_group_admin_id=$(cat .context-data/user-group-admin-id)
identity_broker_profile_tyk_dashboard_data=$(cat deployments/sso/data/tyk-identity-broker/profile-tyk-dashboard.json | \
  sed 's/ORGANISATION_ID/'"$organisation_id"'/' | \
  sed 's/DASHBOARD_USER_API_CREDENTIALS/'"$dashboard_user_api_credentials"'/' | \
  sed 's/DASHBOARD_USER_GROUP_DEFAULT/'"$user_group_default_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_READONLY/'"$user_group_readonly_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_ADMIN/'"$user_group_admin_id"'/')
log_message "  Organisation id: $organisation_id"
log_message "  Dashboard User API Credentials: $dashboard_user_api_credentials"
log_ok
bootstrap_progress

log_message "Setting Identity Broker Profile"
log_http_result "$(curl $identity_broker_base_url/api/profiles/tyk-dashboard -s -w "%{http_code}" -o /dev/null \
  -H "Authorization: $identity_broker_api_credentials" \
  -d "$(echo $identity_broker_profile_tyk_dashboard_data)" 2>> bootstrap.log)"

log_end_deployment

echo -e "\033[2K
▼ SSO
  ▽ Dashboard
    ▾ Organisation 1
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