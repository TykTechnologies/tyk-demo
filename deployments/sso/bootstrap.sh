#!/bin/bash

source scripts/common.sh
deployment="SSO"

cleanup() {
  local exit_code=$? # Capture the exit code of the script
  if [[ $exit_code -ne 0 ]]; then
    log_message "Deployment $deployment bootstrap exited with an error. Exit code: $exit_code"
  fi
}

trap cleanup EXIT

log_start_deployment
bootstrap_progress

log_message "Setting global variables"
dashboard_sso_base_url="http://localhost:3001"
dashboard_base_url_escaped="http:\/\/localhost:3000"
identity_broker_base_url="http://localhost:3010"
log_ok
bootstrap_progress

log_message "Recreating SSO Dashboard to load certificates created during Tyk bootstrap"
eval $(generate_docker_compose_command) up -d --no-deps --force-recreate tyk-dashboard-sso tyk-gateway
wait_for_status "$dashboard_sso_base_url/hello" "200" ".status" "ok" # SSO dashboard
wait_for_liveness "http://localhost:8080/hello" # Gateway used by identity broker for SSO key generation
log_ok

log_message "Getting config data from Identity Broker config file"
identity_broker_api_credentials=$(cat deployments/sso/volumes/tyk-identity-broker/tib.conf | jq -r .Secret)
log_message "  TIB base URL: $identity_broker_base_url"
log_message "  TIB API Credentials: $identity_broker_api_credentials"
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
bootstrap_progress

log_message "Creating profile for LDAP / Token"
identity_broker_profile_ldap_token_data=$(cat deployments/sso/data/tyk-identity-broker/profile-ldap-token.json | \
  sed 's/ORGANISATION_ID/'"$organisation_id"'/' | \
  sed 's/DASHBOARD_HOST/'"$dashboard_base_url_escaped"'/' | \
  sed 's/DASHBOARD_USER_API_CREDENTIALS/'"$dashboard_user_api_credentials"'/')
bootstrap_progress

log_message "Write profiles to profiles.json file"
profile_temp=$(cat deployments/sso/volumes/tyk-identity-broker/profiles.json)
jq -n '[ $profile1, $profile2 ]' \
  --argjson profile1 "$identity_broker_profile_tyk_dashboard_data" \
  --argjson profile2 "$identity_broker_profile_ldap_token_data" \
  > deployments/sso/volumes/tyk-identity-broker/profiles.json
bootstrap_progress

log_message "Restart TIB to load new profiles"
eval $(generate_docker_compose_command) restart tyk-identity-broker 1> /dev/null 2>> logs/bootstrap.log
log_ok

log_message "Waiting for OpenLDAP server to be ready"
until docker exec -i tyk-demo-ldap-server-1 ldapsearch -x -D "cn=admin,dc=tyk,dc=io" -w admin -b "dc=tyk,dc=io" "(objectClass=*)" &> /dev/null; do
  log_message "  OpenLDAP server is not ready yet. Retrying in 1 seconds..."
  bootstrap_progress
  sleep 1
done
log_ok
bootstrap_progress

log_message "Adding 'Users' OU to OpenLDAP"
docker exec tyk-demo-ldap-server-1 ldapadd -x -D "cn=admin,dc=tyk,dc=io" -w admin -f "/ldap/ou-users.ldif" > /dev/null 2>> logs/bootstrap.log
if [[ $? -ne 0 ]]; then
  log_message "ERROR: Could not add Users OU to OpenLDAP"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Adding 'Test' user to OpenLDAP"
docker exec  tyk-demo-ldap-server-1 ldapadd -x -D "cn=admin,dc=tyk,dc=io" -w admin -f "/ldap/user-test.ldif" > /dev/null 2>> logs/bootstrap.log
if [[ $? -ne 0 ]]; then
  log_message "ERROR: Could not add test user to OpenLDAP"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Allow anonymous queries to OpenLDAP"
docker exec -i tyk-demo-ldap-server-1 ldapmodify -Y EXTERNAL -H ldapi:/// -f /ldap/anonymous-access.ldif > /dev/null 2>> logs/bootstrap.log
if [[ $? -ne 0 ]]; then
  log_message "ERROR: Could not allow anonymous access to OpenLDAP"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Verifying that test user was added to OpenLDAP"
attempts=0
max_attempts=5
until docker exec -i tyk-demo-ldap-server-1 ldapsearch -x -b "dc=tyk,dc=io" "(uid=test)" | grep -q "dn: uid=test,ou=users,dc=tyk,dc=io"; do
  if [[ $attempts -ge $max_attempts ]]; then
    log_message "ERROR: User uid=test not found after $max_attempts attempts."
    exit 1
  fi
  log_message "User uid=test not found. Retrying in 1 second... (Attempt $((attempts + 1))/$max_attempts)"
  attempts=$((attempts + 1))
  sleep 1
done
log_ok
bootstrap_progress

# do this to prevent git from showing changes in the profiles.json file :(
sleep 2
echo "$profile_temp" > deployments/sso/volumes/tyk-identity-broker/profiles.json

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
      ▿ OIDC / Dashboard
                    URL : $identity_broker_base_url/auth/tyk-dashboard/openid-connect
      ▿ LDAP / Token
                    URL : $identity_broker_base_url/auth/ldap-token/1"