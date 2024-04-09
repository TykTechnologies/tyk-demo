#!/bin/bash

source scripts/common.sh
deployment="Portal"

log_start_deployment
bootstrap_progress

# Grab the Dashboard License line from ENV file
licence_line=$(grep "DASHBOARD_LICENCE=" .env)
# Parse out the DASHBOARD_LICENSE= bit
encoded_licence_jwt=$(echo $licence_line | sed -E 's/^[A-Z_]+=(.+)$/\1/')

# Get Tyk Dashboard API Access Credentials
dashboard_user_api_credentials=$(cat .context-data/1-dashboard-user-1-api-key)
dashboard_user_org_id=$(cat .context-data/1-organisation-1-id)
# Export to envs for docker
log_message "Exporting Docker Environment Variables for Enterprise Portal in .env"
set_docker_environment_value "ADMIN_EMAIL" $(cat .context-data/1-dashboard-user-1-email)
set_docker_environment_value "ADMIN_PASSWORD" $(cat .context-data/1-dashboard-user-1-password)
set_docker_environment_value "ADMIN_ORG_ID" $dashboard_user_org_id
set_docker_environment_value "TYK_DASHBOARD_API_ACCESS_CREDENTIALS" $dashboard_user_api_credentials

# Postgres Env configuration for tyk portal
set_docker_environment_value "PORTAL_HOST_PORT" 3001
set_docker_environment_value "PORTAL_DATABASE_DIALECT" postgres
set_docker_environment_value "POSTGRES_PASSWORD" secr3t
set_docker_environment_value "PORTAL_DATABASE_CONNECTIONSTRING" "host=tyk-portal-postgres port=5432 dbname=portal user=admin password=$(grep "POSTGRES_PASSWORD=" .env | sed -E 's/^[A-Z_]+=(.+)$/\1/') sslmode=disable"
set_docker_environment_value "PORTAL_DATABASE_ENABLELOGS" true
set_docker_environment_value "PORTAL_THEMING_THEME" default
set_docker_environment_value "PORTAL_THEMING_PATH" ./themes
set_docker_environment_value "PORTAL_LICENSEKEY" $encoded_licence_jwt
set_docker_environment_value "PORTAL_DOCRENDERER" stoplight
set_docker_environment_value "PORTAL_REFRESHINTERVAL" 10
set_docker_environment_value "PORTAL_LOG_LEVEL" debug
set_docker_environment_value "PORTAL_LOG_FORMAT" dev


# Create Plans and Policies for NEW Developer Portal
log_message "Creating Enterprise Portal Plans"
for file in deployments/portal/data/plans/*; do
  if [[ -f $file ]]; then
  	policy=`cat $file`
    plan_name=$(jq -r '.name' $file)
    log_message "  Creating Plan: $plan_name"
    curl http://tyk-dashboard.localhost:3000/api/portal/policies -s \
      -o /dev/null \
      -H "authorization: $dashboard_user_api_credentials" \
      -d "$policy"
  fi
  bootstrap_progress
done
log_ok

log_message "Creating Enterprise Portal Products ..."
for file in deployments/portal/data/products/*; do
  if [[ -f $file ]]; then
  	product=`cat $file`
    product_name=$(jq -r '.name' $file)
    log_message "  Creating Product: $product_name"
    curl http://tyk-dashboard.localhost:3000/api/portal/policies -s \
      -o /dev/null \
      -H "authorization: $dashboard_user_api_credentials" \
      -d "$product"
  fi
  bootstrap_progress
done
log_ok

log_message "Recreating tyk-portal-postgres for new env vars"
$(generate_docker_compose_command) rm -f -s tyk-portal-postgres 1>/dev/null 2>&1
$(generate_docker_compose_command) up -d tyk-portal-postgres 2>/dev/null
bootstrap_progress log_ok

log_message "Recreating tyk-portal for new env vars"
$(generate_docker_compose_command) rm -f -s tyk-portal 1>/dev/null 2>&1
$(generate_docker_compose_command) up -d tyk-portal 2>/dev/null
bootstrap_progress
log_ok

portal_admin_user_email=$(cat .context-data/1-dashboard-user-1-email)
portal_admin_user_password=$(cat .context-data/1-dashboard-user-1-password)

log_message "Waiting for Tyk-Portal container to come online ..."
wait_for_response "http://tyk-portal.localhost:3100/ready" "200"
sleep 5 #TODO: Deprecate this when advanced ready endpoint is available

log_message "Bootstrapping the Portal Admin ..."
# Need to loop this to wait for portal to come online
api_response=$(curl 'http://tyk-portal.localhost:3100/portal-api/bootstrap' -s \
  -H 'Content-Type: application/json' \
  --data-raw '{
    "username":"'$portal_admin_user_email'",
    "password": "'$portal_admin_user_password'",
    "first_name":"James",
    "last_name":"Brown"
  }')
log_message "access_token: $api_response"
log_ok
bootstrap_progress

portal_admin_api_token=$(echo $api_response | jq -r .data.api_token)
set_docker_environment_value "PORTAL_ADMIN_API_TOKEN" $portal_admin_api_token

log_message "Waiting for the bootstrap to complete ..."
sleep 5 #TODO: Deprecate this when advanced ready endpoint is available

# Configure Provider settings for Tyk-Dashboard
log_message "Creating the Provider ..."
api_response=$(curl --location 'http://tyk-portal.localhost:3100/portal-api/providers' -s \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: $portal_admin_api_token" \
--data '{
  "Configuration": {
    "MetaData": "{\"URL\":\"http://tyk-dashboard:3000\",\"Secret\":\"'$dashboard_user_api_credentials'\",\"OrgID\":\"'$dashboard_user_org_id'\",\"Gateway\":\"\",\"PoliciesTags\":[],\"InsecureSkipVerify\":false}"
  },
  "Name": "Tyk Demo Dashboard",
  "Type": "tyk-pro"
}')
provider_id=$(echo $api_response | jq -r .ID)
log_ok
bootstrap_progress

log_message "Synchronizing the Provider with ID: $provider_id"
api_response=$(curl --location --request PUT "http://tyk-portal.localhost:3100/portal-api/providers/$provider_id/synchronize" -s \
--header "Accept: application/json" \
--header "Authorization: $portal_admin_api_token")
log_message "api_response: $(echo $api_response | jq -r .message)"
log_ok
bootstrap_progress


# Create Organizations
log_message "Creating the Portal Organizations"
api_response=$(curl --location 'http://tyk-portal.localhost:3100/portal-api/organisations' -s \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "Authorization: $portal_admin_api_token" \
  --data '{
    "Name": "Internal Developers Organization"
}')
internal_developers_org_id=$(echo $api_response | jq -r .ID)
log_message "Internal Developers Org ID: $internal_developers_org_id"


api_response=$(curl --location 'http://tyk-portal.localhost:3100/portal-api/organisations' -s \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "Authorization: $portal_admin_api_token" \
  --data '{
    "Name": "External Developers and Partners Organization"
}')
external_developers_org_id=$(echo $api_response | jq -r .ID)
log_message "Enternal Developers Org ID: $external_developers_org_id"

# Create Users
api_response=$(curl --location 'http://tyk-portal.localhost:3100/portal-api/users' -s \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: $portal_admin_api_token" \
--data-raw '{
  "Active": "true",
  "Email": "api-developer@internal.org",
  "First": "Sleve",
  "Last": "McDichal",
  "Organisation": {"ID": "'$internal_developers_org_id'"},
  "Role": "consumer-admin",
  "Provider": "password",
  "ResetPassword": "false",
  "Teams": "'$internal_developers_org_id'",
  "Password": "password"
}')

api_response=$(curl --location 'http://tyk-portal.localhost:3100/portal-api/users' -s \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: $portal_admin_api_token" \
--data-raw '{
  "Active": "true",
  "Email": "api-consumer@external.org",
  "First": "Willie",
  "Last": "Dustice",
  "Organisation": {"ID": "'$external_developers_org_id'"},
  "Role": "consumer-admin",
  "Provider": "password",
  "ResetPassword": "false",
  "Teams": "'$external_developers_org_id'",
  "Password": "password"
}')

# Construct the Payload for Updating the Internal API Products
internal_products=$(curl --location 'http://tyk-portal.localhost:3100/portal-api/products/1' -s \
--header 'Accept: application/json' \
--header "Authorization: $portal_admin_api_token")

internal_products=$(echo $internal_products | jq -r '.Description = "Internal APIs For Developers"')
internal_products=$(echo $internal_products | jq -r '.Catalogues = [2]')
internal_products=$(echo $internal_products | jq -r '.APIDetails[0].OASUrl = "https://httpbin.org/spec.json"')

api_response=$(curl --location --request PUT 'http://tyk-portal.localhost:3100/portal-api/products/1' -s \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: $portal_admin_api_token" \
--data "$internal_products")

# Construct the Payload for Updating the External API Products
external_products=$(curl --location 'http://tyk-portal.localhost:3100/portal-api/products/2' -s \
--header 'Accept: application/json' \
--header "Authorization: $portal_admin_api_token")

external_products=$(echo $external_products | jq -r '.Description = "External APIs For Consumers and Partners"')
external_products=$(echo $external_products | jq -r '.Catalogues = [1]')
external_products=$(echo $external_products | jq -r '.APIDetails[0].OASUrl = "https://httpbin.org/spec.json"')

api_response=$(curl --location --request PUT 'http://tyk-portal.localhost:3100/portal-api/products/2' -s \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: $portal_admin_api_token" \
--data "$external_products")

log_message "Updating Plans for correct listing in Catalogues"
all_plans=$(curl --location 'http://tyk-portal.localhost:3100/portal-api/plans' -s \
--header 'Accept: application/json' \
--header "Authorization: $portal_admin_api_token")

# Get the IDs of plans in the Portal
plans=($(echo $all_plans | jq -r '.[].ID'))

# For each Plan, update where it belongs
for plan in "${plans[@]}"; do
  sleep 0.75
  plan_response=$(curl --location "http://tyk-portal.localhost:3100/portal-api/plans/$plan" -s \
  --header 'Accept: application/json' \
  --header "Authorization: $portal_admin_api_token")
  plan_response=$(echo $plan_response | jq -r '.Catalogues = [1]')
  plan_response=$(echo $plan_response | jq -r '.Quota = -1')
  if [ "$plan" -ge 2 ]
  then
    plan_response=$(echo $plan_response | jq -r '.Catalogues = [1, 2]')
  fi
  api_response=$(curl --location --request PUT 'http://tyk-portal.localhost:3100/portal-api/plans/2' -s \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "Authorization: $portal_admin_api_token" \
  --data "$plan_response")
  log_message "PLAN UPDATED: $api_response"
  unset api_response plan_response
done

log_ok
bootstrap_progress












log_end_deployment
# Echo credentials for Admin, Example Developer and Example Consumer
echo -e "\033[2K
▼ Portal
  ▽ Enterprise Portal ($(get_service_image_tag "tyk-portal"))
                    URL : http://tyk-portal.localhost:3100/
         Admin Username : $portal_admin_user_email
         Admin Password : $portal_admin_user_password
         Admin API Key  : $portal_admin_api_token
    ▾ (Internal) Developer
               Username : api-developer@internal.org
               Password : password
    ▾ (External) Consumer
                  Email : api-consumer@external.org
               Password : password"
