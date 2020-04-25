#!/bin/bash

echo "    Dashboard (e2)"

e2_dashboard_base_url="http://localhost:3002"
e2_gateway_base_url="http://localhost:8085"

dashboard_admin_api_credentials=$(cat ./volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
# portal_root_path=$(cat ./volumes/tyk-dashboard/tyk_analytics.conf | jq -r .host_config.portal_root_path)

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

cat <<EOF                 
               URL : $e2_dashboard_base_url
          Username : $dashboard_user_email
          Password : $dashboard_user_password
   API Credentials : $e2_dashboard_user_api_credentials

           Gateway
               URL : $e2_gateway_base_url (Environment 2)
               
EOF