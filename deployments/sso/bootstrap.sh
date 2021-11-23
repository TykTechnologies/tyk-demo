#!/bin/bash

source scripts/common.sh
deployment="SSO"
log_start_deployment
bootstrap_progress

log_message "Setting global variables"
dashboard_sso_base_url="http://localhost:3001"
dashboard_base_url_escaped="http:\/\/localhost:3000"
identity_broker_base_url="http://localhost:3010"
log_ok
bootstrap_progress

log_message "Getting config data from Identity Broker config file"
identity_broker_api_credentials=$(cat deployments/sso/volumes/tyk-identity-broker/tib.conf | jq -r .Secret)
log_message "  TIB base URL: $identity_broker_base_url"
log_message "  TIB API Credentials: $identity_broker_api_credentials"
log_ok
bootstrap_progress

log_message "Ensuring that profiles.json file is present in Identity Broker container"
eval "$(generate_docker_compose_command) exec -T tyk-identity-broker sh -c \"touch /opt/tyk-identity-broker/profiles.json\""
if [ "$?" != 0 ]; then
  echo "Error occurred when touching profiles.json"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Reading context data to be used to create SSO profiles"
organisation_id=$(get_context_data "1" "organisation" "1" "id")
dashboard_user_api_credentials=$(get_context_data "1" "dashboard-user" "1" "api-key")
user_group_readonly_id=$(get_context_data "1" "dashboard-user-group" "1" "id")
user_group_default_id=$(get_context_data "1" "dashboard-user-group" "2" "id")
user_group_admin_id=$(get_context_data "1" "dashboard-user-group" "3" "id")
log_message "  Organisation Id: $organisation_id"
log_message "  Dashboard User API Credentials: $dashboard_user_api_credentials"
log_message "  Dashboard \"Readonly\" User Group Id: $user_group_readonly_id"
log_message "  Dashboard \"Default\" User Group Id: $user_group_default_id"
log_message "  Dashboard \"Admin\" User Group Id: $user_group_admin_id"
log_ok
bootstrap_progress

log_message "Creating profile for OICD / Dashboard"
identity_broker_profile_tyk_dashboard_data=$(cat deployments/sso/data/tyk-identity-broker/profile-tyk-dashboard.json | \
  sed 's/ORGANISATION_ID/'"$organisation_id"'/' | \
  sed 's/DASHBOARD_USER_API_CREDENTIALS/'"$dashboard_user_api_credentials"'/' | \
  sed 's/DASHBOARD_USER_GROUP_DEFAULT/'"$user_group_default_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_READONLY/'"$user_group_readonly_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_ADMIN/'"$user_group_admin_id"'/')
log_http_result "$(curl $identity_broker_base_url/api/profiles/tyk-dashboard -s -w "%{http_code}" -o /dev/null \
  -H "Authorization: $identity_broker_api_credentials" \
  -d "$(echo $identity_broker_profile_tyk_dashboard_data)" 2>> bootstrap.log)"
bootstrap_progress

log_message "Creating profile for LDAP / Token"
identity_broker_profile_ldap_token_data=$(cat deployments/sso/data/tyk-identity-broker/profile-ldap-token.json | \
  sed 's/ORGANISATION_ID/'"$organisation_id"'/' | \
  sed 's/DASHBOARD_HOST/'"$dashboard_base_url_escaped"'/' | \
  sed 's/DASHBOARD_USER_API_CREDENTIALS/'"$dashboard_user_api_credentials"'/')
log_http_result "$(curl $identity_broker_base_url/api/profiles/ldap-token -s -w "%{http_code}" -o /dev/null \
  -H "Authorization: $identity_broker_api_credentials" \
  -d "$(echo $identity_broker_profile_ldap_token_data)" 2>> bootstrap.log)"
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ SSO
  ▽ Dashboard ($(get_service_image_tag "tyk-dashboard-sso"))
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
  ▽ Identity Broker ($(get_service_image_tag "tyk-identity-broker"))
    ▾ SSO Endpoints
       OIDC / Dashboard : $identity_broker_base_url/auth/tyk-dashboard/openid-connect
           LDAP / Token : $identity_broker_base_url/auth/ldap-token/1"