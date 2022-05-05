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

# Export to envs for docker
log_message "Exporting Docker Environment Variables for Enterprise Portal in .env"
set_docker_environment_value "ADMIN_EMAIL" $(cat .context-data/1-dashboard-user-1-email)
set_docker_environment_value "ADMIN_PASSWORD" $(cat .context-data/1-dashboard-user-1-password)
set_docker_environment_value "ADMIN_ORG_ID" $(cat .context-data/1-organisation-1-id)
set_docker_environment_value "PORTAL_HOST_PORT" 3001
set_docker_environment_value "PORTAL_REFRESHINTERVAL" 10
set_docker_environment_value "PORTAL_THEMING_THEME" default
set_docker_environment_value "PORTAL_THEMING_PATH" ./themes
set_docker_environment_value "PORTAL_LICENSEKEY" $encoded_licence_jwt
set_docker_environment_value "TYK_DASHBOARD_API_ACCESS_CREDENTIALS" $dashboard_user_api_credentials

# Create Plans and Policies for NEW Developer Portal
log_message "Creating Enterprise Portal Plans"
for file in deployments/portal/data/tyk-portal/plans/*; do 
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
for file in deployments/portal/data/tyk-portal/products/*; do 
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

# Restoring a default "seed" of the database
log_message "Copying portal.db.bak to portal.db ..."
cp deployments/portal/data/tyk-portal/database/portal.db.bak deployments/portal/data/tyk-portal/database/portal.db
log_ok

# Update the portal database with the proper access credentials for loading a bootstrapped portal
log_message "Updating Portal DB With new TYK_DASHBOARD_API_ACCESS_CREDENTIALS"
./deployments/portal/update_database.sh
log_ok

log_message "Recreating tyk-portal for new env vars"
$(generate_docker_compose_command) rm -f -s tyk-portal 1>/dev/null 2>&1
$(generate_docker_compose_command) up -d tyk-portal 2>/dev/null
bootstrap_progress
log_ok


log_end_deployment

portal_admin_user_email=$(cat .context-data/1-dashboard-user-1-email)
portal_admin_user_password=$(cat .context-data/1-dashboard-user-1-password)


# Echo credentials for Admin, Example Developer and Example Consumer
echo -e "\033[2K 
▼ Portal
  ▽ Enterprise Portal ($(get_service_image_tag "tyk-portal"))
                    URL : http://tyk-portal.localhost:3100/
         Admin Username : $portal_admin_user_email
         Admin Password : $portal_admin_user_password

      (Internal) Developer Username : api-developer@internal.org
      (Interlal) Developer Password : password

          (External) Consumer Email : api-consumer@external.org
          (External) Consumer Email : password"
