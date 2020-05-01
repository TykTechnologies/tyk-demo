#!/bin/bash

e2_dashboard_base_url="http://localhost:3002"
e2_gateway_base_url="http://localhost:8085"
dashboard_admin_api_credentials=$(cat ./volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)

e2_status=""
e2_status_desired="200"
e2_tries=0

while [ "$e2_status" != "$e2_status_desired" ]
do
  e2_tries=$((e2_tries+1))
  dot=$(printf "%-${e2_tries}s" ".")
  echo -ne "  Bootstrapping Tyk Environment 2 ${dot// /.} \r"
  e2_status=$(curl -I -m2 $e2_dashboard_base_url/admin/organisations -H "admin-auth: $dashboard_admin_api_credentials" 2>/dev/null | head -n 1 | cut -d$' ' -f2)
  
  if [ "$e2_status" != "$e2_status_desired" ]
  then
    sleep 1
  fi
done

curl $e2_dashboard_base_url/admin/organisations/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/organisation.json > /dev/null

dashboard_user_email=$(jq -r '.email_address' bootstrap-data/tyk-dashboard/dashboard-user.json)
dashboard_user_password=$(jq -r '.password' bootstrap-data/tyk-dashboard/dashboard-user.json)
e2_dashboard_user_api_response=$(curl $e2_dashboard_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/dashboard-user.json \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
e2_dashboard_user_id=$(echo $e2_dashboard_user_api_response | jq -r '.id')
e2_dashboard_user_api_credentials=$(echo $e2_dashboard_user_api_response | jq -r '.api_key')
curl $e2_dashboard_base_url/api/users/$e2_dashboard_user_id/actions/reset -s \
  -H "authorization: $e2_dashboard_user_api_credentials" \
  --data-raw '{
      "new_password":"'$dashboard_user_password'",
      "user_permissions": { "IsAdmin": "admin" }
    }' > /dev/null




echo -e "\033[2K   Env 2 Dashboard
               URL : $e2_dashboard_base_url
          Username : $dashboard_user_email
          Password : $dashboard_user_password
   API Credentials : $e2_dashboard_user_api_credentials

     Env 2 Gateway
               URL : $e2_gateway_base_url
"