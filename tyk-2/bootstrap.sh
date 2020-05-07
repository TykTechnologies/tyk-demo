#!/bin/bash

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping Tyk Environment 2 ${dots// /.} \r"
}

dashboard2_base_url="http://localhost:3002"
gateway2_base_url="http://localhost:8085"
dashboard_admin_api_credentials=$(cat tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)

status=""
status_desired="200"

while [ "$status" != "$status_desired" ]
do
  status=$(curl -I -m2 $dashboard2_base_url/admin/organisations -H "admin-auth: $dashboard_admin_api_credentials" 2>/dev/null | head -n 1 | cut -d$' ' -f2)  
  if [ "$status" != "$status_desired" ]
  then
    sleep 1
  fi
  bootstrap_progress
done

curl $dashboard2_base_url/admin/organisations/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @tyk/bootstrap/tyk-dashboard/organisation.json > /dev/null
bootstrap_progress

dashboard_user_email=$(jq -r '.email_address' tyk/bootstrap/tyk-dashboard/dashboard-user.json)
dashboard_user_password=$(jq -r '.password' tyk/bootstrap/tyk-dashboard/dashboard-user.json)
dashboard2_user_api_response=$(curl $dashboard2_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @tyk/bootstrap/tyk-dashboard/dashboard-user.json \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard2_user_id=$(echo $dashboard2_user_api_response | jq -r '.id')
dashboard2_user_api_credentials=$(echo $dashboard2_user_api_response | jq -r '.api_key')
bootstrap_progress

curl $dashboard2_base_url/api/users/$dashboard2_user_id/actions/reset -s \
  -H "authorization: $dashboard2_user_api_credentials" \
  --data-raw '{
      "new_password":"'$dashboard_user_password'",
      "user_permissions": { "IsAdmin": "admin" }
    }' > /dev/null

echo -e "\033[2K   Env 2 Dashboard
               URL : $dashboard2_base_url
          Username : $dashboard_user_email
          Password : $dashboard_user_password
   API Credentials : $dashboard2_user_api_credentials

     Env 2 Gateway
               URL : $gateway2_base_url
"