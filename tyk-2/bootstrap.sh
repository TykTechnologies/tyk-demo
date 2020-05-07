#!/bin/bash

echo "Begin Tyk environment 2 bootstrap" >>bootstrap.log

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

echo "Wait for Tyk environment 2 Dashboard to respond ok" >>bootstrap.log
while [ "$status" != "$status_desired" ]
do
  status=$(curl -I -s -m2 $dashboard2_base_url/admin/organisations -H "admin-auth: $dashboard_admin_api_credentials" 2>>bootstrap.log | head -n 1 | cut -d$' ' -f2)  
  if [ "$status" != "$status_desired" ]
  then
    echo "Tyk environment 2 Dashboard status:$status" >>bootstrap.log
    sleep 1
  fi
  bootstrap_progress
done

echo "Import organisation" >>bootstrap.log
curl $dashboard2_base_url/admin/organisations/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @tyk/data/tyk-dashboard/organisation.json 2>>bootstrap.log
bootstrap_progress

echo "Create Dashboard user" >>bootstrap.log
dashboard_user_email=$(jq -r '.email_address' tyk/data/tyk-dashboard/dashboard-user.json)
dashboard_user_password=$(jq -r '.password' tyk/data/tyk-dashboard/dashboard-user.json)
dashboard2_user_api_response=$(curl $dashboard2_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @tyk/data/tyk-dashboard/dashboard-user.json 2>>bootstrap.log \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard2_user_id=$(echo $dashboard2_user_api_response | jq -r '.id')
dashboard2_user_api_credentials=$(echo $dashboard2_user_api_response | jq -r '.api_key')
bootstrap_progress

echo "Reset Dashboard user password" >>bootstrap.log
curl $dashboard2_base_url/api/users/$dashboard2_user_id/actions/reset -s \
  -H "authorization: $dashboard2_user_api_credentials" \
  --data-raw '{
      "new_password":"'$dashboard_user_password'",
      "user_permissions": { "IsAdmin": "admin" }
    }' 2>>bootstrap.log
bootstrap_progress

echo "End Tyk environment 2 bootstrap" >>bootstrap.log

echo -e "\033[2K   Env 2 Dashboard
               URL : $dashboard2_base_url
          Username : $dashboard_user_email
          Password : $dashboard_user_password
   API Credentials : $dashboard2_user_api_credentials

     Env 2 Gateway
               URL : $gateway2_base_url
"