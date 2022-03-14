#!/bin/bash

source scripts/common.sh
deployment="portal"

log_start_deployment
bootstrap_progress

dashboard_user_api_credentials=$(cat .context-data/1-dashboard-user-1-api-key)

set_docker_environment_value "TYK_DASHBOARD_API_ACCESS_CREDENTIALS" $dashboard_user_api_credentials

# Grab the Dashboard License line from ENV file
licence_line=$(grep "DASHBOARD_LICENCE=" .env)
# Parse out the DASHBOARD_LICENSE= bit
encoded_licence_jwt=$(echo $licence_line | sed -E 's/^[A-Z_]+=(.+)$/\1/')

# Copy portal.conf.example to portal.conf for proper usage
cp deployments/portal/volumes/tyk-portal/portal.conf.example deployments/portal/volumes/tyk-portal/portal.conf
# Replace portal.conf license variable w/ proper license key
find deployments/portal/volumes/tyk-portal/portal.conf -type f -exec sed -i '' "s/REPLACE_VALUE_HERE/$encoded_licence_jwt/g" {} \;


log_message "Restarting tyk-portal."
$(generate_docker_compose_command) stop tyk-portal 2> /dev/null
$(generate_docker_compose_command) rm -f tyk-portal 2> /dev/null
$(generate_docker_compose_command) up -d tyk-portal 2> /dev/null

log_ok

# Create Plans and Policies for NEW Developer Portal
log_message "Creating Enterprise Portal Plans"
for file in deployments/portal/volumes/tyk-portal/plans/*; do 
  if [[ -f $file ]]; then
  	policy=`cat $file`
    curl http://tyk-dashboard.localhost:3000/api/portal/policies -s \
      -o /dev/null \
      -H "authorization: $dashboard_user_api_credentials" \
      -d "$policy"
  fi
done

log_message "Creating Enterprise Portal Products"
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
               Hosted At: http://localhost:3100/
               Admin Username : $portal_admin_user_email
               Admin Password : $portal_admin_user_password
"