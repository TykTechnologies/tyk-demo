#!/bin/bash

source scripts/common.sh
deployment="portal"

log_start_deployment
bootstrap_progress


# Grab the Dashboard License line from ENV file
licence_line=$(grep "DASHBOARD_LICENCE=" .env)
# Parse out the DASHBOARD_LICENSE= bit
encoded_licence_jwt=$(echo $licence_line | sed -E 's/^[A-Z_]+=(.+)$/\1/')

# Get Tyk Dashboard API Access Credentials
dashboard_user_api_credentials=$(cat .context-data/1-dashboard-user-1-api-key)

log_message "Exporting Docker Environment Variables for Enterprise Portal in .env"

# Export to envs for docker
set_docker_environment_value "ADMIN_EMAIL" $(cat .context-data/1-dashboard-user-1-email)
set_docker_environment_value "ADMIN_PASSWORD" $(cat .context-data/1-dashboard-user-1-password)
set_docker_environment_value "ADMIN_ORG_ID" $(cat .context-data/1-organisation-1-id)
set_docker_environment_value "PORTAL_HOST_PORT" 3001
set_docker_environment_value "PORTAL_REFRESHINTERVAL" 10
set_docker_environment_value "PORTAL_THEMING_THEME" default
set_docker_environment_value "PORTAL_THEMING_PATH" ./themes
set_docker_environment_value "PORTAL_LICENSEKEY" $encoded_licence_jwt
set_docker_environment_value "TYK_DASHBOARD_API_ACCESS_CREDENTIALS" $dashboard_user_api_credentials


log_message "Restarting tyk-portal ... "
$(generate_docker_compose_command) stop tyk-portal 2> /dev/null
$(generate_docker_compose_command) rm -f tyk-portal 2> /dev/null
$(generate_docker_compose_command) up -d tyk-portal 2> /dev/null

log_ok

# Create Plans and Policies for NEW Developer Portal
log_message "Creating Enterprise Portal Plans ..."
for file in deployments/portal/volumes/tyk-portal/plans/*; do 
  if [[ -f $file ]]; then
  	policy=`cat $file`
    curl http://tyk-dashboard.localhost:3000/api/portal/policies -s \
      -o /dev/null \
      -H "authorization: $dashboard_user_api_credentials" \
      -d "$policy"
  fi
done

log_message "Creating Enterprise Portal Products ..."
for file in deployments/portal/volumes/tyk-portal/products/*; do 
  if [[ -f $file ]]; then
  	policy=`cat $file`
    curl http://tyk-dashboard.localhost:3000/api/portal/policies -s \
      -o /dev/null \
      -H "authorization: $dashboard_user_api_credentials" \
      -d "$policy"
  fi
done

log_ok

portal_admin_user_email=$(cat .context-data/1-dashboard-user-1-email)
portal_admin_user_password=$(cat .context-data/1-dashboard-user-1-password)

echo -e "\033[2K 
  ▽ Enterprise Portal ($(get_service_image_tag "tyk-portal"))
               Hosted At: http://tyk-portal.localhost:3100/
               Admin Username : $portal_admin_user_email
               Admin Password : $portal_admin_user_password
"