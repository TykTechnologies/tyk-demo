#!/bin/bash

dashboard_base_url="http://localhost:3000"
dashboard_sso_base_url="http://localhost:3001"
gateway_base_url="http://localhost:8080"
gateway_tls_base_url="https://localhost:8081"
kibana_base_url="http://localhost:5601"
identity_broker_base_url="http://localhost:3010"

echo "Making scripts executable"
chmod +x dump.sh
chmod +x sync.sh
chmod +x add-gateway.sh
echo "  Done"

echo "Getting Dashboard Configuration"
dashboard_admin_api_credentials=$(cat ./volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
portal_root_path=$(cat ./volumes/tyk-dashboard/tyk_analytics.conf | jq -r .host_config.portal_root_path)
echo "  Dashboard Admin API Credentials: $dashboard_admin_api_credentials"
echo "  Portal Root Path: $portal_root_path"

echo "Importing Organisation"
organisation_id=$(curl $dashboard_base_url/admin/organisations/import \
  --silent \
  --header "admin-auth: $dashboard_admin_api_credentials" \
  --data @bootstrap-data/tyk-dashboard/organisation.json \
  | jq -r '.Meta')
echo $organisation_id > .organisation-id
echo "  Organisation Id: $organisation_id"

echo "Creating Dashboard user"
dashboard_user_email=$(jq -r '.email_address' bootstrap-data/tyk-dashboard/dashboard-user.json)
dashboard_user_api_response=$(curl $dashboard_base_url/admin/users \
  --silent \
  --header "admin-auth: $dashboard_admin_api_credentials" \
  --data @bootstrap-data/tyk-dashboard/dashboard-user.json \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard_user_id=$(echo $dashboard_user_api_response | jq -r '.id')
dashboard_user_api_credentials=$(echo $dashboard_user_api_response | jq -r '.api_key')
dashboard_user_password=$(jq -r '.password' bootstrap-data/tyk-dashboard/dashboard-user.json)
curl $dashboard_base_url/api/users/$dashboard_user_id/actions/reset \
  --silent \
  --header "authorization: $dashboard_user_api_credentials" \
  --data-raw '{
      "new_password":"'$dashboard_user_password'",
      "user_permissions": { "IsAdmin": "admin" }
    }' \
  > /dev/null
echo $dashboard_user_api_credentials > .dashboard-user-api-credentials
echo "  Username: $dashboard_user_email"
echo "  Password: $dashboard_user_password"
echo "  Dashboard API Credentials: $dashboard_user_api_credentials"
echo "  ID: $dashboard_user_id"

echo "Creating Dashboard User Groups"
curl $dashboard_base_url/api/usergroups \
  --silent \
  --header "Authorization: $dashboard_user_api_credentials" \
  --data @bootstrap-data/tyk-dashboard/usergroup-readonly.json \
  > /dev/null
curl $dashboard_base_url/api/usergroups \
  --silent \
  --header "Authorization: $dashboard_user_api_credentials" \
  --data @bootstrap-data/tyk-dashboard/usergroup-default.json \
  > /dev/null
curl $dashboard_base_url/api/usergroups \
  --silent \
  --header "Authorization: $dashboard_user_api_credentials" \
  --data @bootstrap-data/tyk-dashboard/usergroup-admin.json \
  > /dev/null
user_group_data=$(curl $dashboard_base_url/api/usergroups \
  --silent \
  --header "Authorization: $dashboard_user_api_credentials")
user_group_readonly_id=$(echo $user_group_data | jq -r .groups[0].id)
user_group_default_id=$(echo $user_group_data | jq -r .groups[1].id)
user_group_admin_id=$(echo $user_group_data | jq -r .groups[2].id)
echo "  Done"

echo "Creating Portal default settings"
curl $dashboard_base_url/api/portal/catalogue \
  --silent \
  --header "Authorization: $dashboard_user_api_credentials" \
  --data '{"org_id": "'$organisation_id'"}' \
  > /dev/null
curl $dashboard_base_url/api/portal/configuration \
  --silent \
  --header "Authorization: $dashboard_user_api_credentials" \
  --data "{}" \
  > /dev/null
echo "  Done"

echo "Creating Portal home page"
curl $dashboard_base_url/api/portal/pages \
  --silent \
  --header "Authorization: $dashboard_user_api_credentials" \
  --data @bootstrap-data/tyk-dashboard/portal-home-page.json \
  > /dev/null
echo "  Done"

echo "Creating Portal user"
portal_user_email=$(jq -r '.email' bootstrap-data/tyk-dashboard/portal-user.json)
portal_user_password=$(openssl rand -base64 12)
curl $dashboard_base_url/api/portal/developers \
  --silent \
  --header "Authorization: $dashboard_user_api_credentials" \
  --data '{
      "email": "'$portal_user_email'",
      "password": "'$portal_user_password'",
      "org_id": "'$organisation_id'"   
    }' \
  > /dev/null
echo "  Done"

echo "Synchronising APIs and Policies"
tyk-sync sync -d $dashboard_base_url -s $dashboard_user_api_credentials -o $organisation_id -p tyk-sync-data
echo "  Done"

echo "Creating Identity Broker Profiles"
identity_broker_api_credentials=$(cat ./volumes/tyk-identity-broker/tib.conf | jq -r .Secret)
identity_broker_profile_tyk_dashboard_data=$(cat ./bootstrap-data/tyk-identity-broker/profile-tyk-dashboard.json | \
  sed 's/DASHBOARD_USER_API_CREDENTIALS/'"$dashboard_user_api_credentials"'/' | \
  sed 's/DASHBOARD_USER_GROUP_DEFAULT/'"$user_group_default_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_READONLY/'"$user_group_readonly_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_ADMIN/'"$user_group_admin_id"'/')
curl $identity_broker_base_url/api/profiles/tyk-dashboard \
  --silent \
  --header "Authorization: $identity_broker_api_credentials" \
  --data "$(echo $identity_broker_profile_tyk_dashboard_data)" \
  > /dev/null
echo "  Done"

echo "Waiting for Kibana to be available (please be patient)"
kibana_status=""
while [ "$kibana_status" != "200" ]
do
  kibana_status=$(curl -I $kibana_base_url/app/kibana 2>/dev/null | head -n 1 | cut -d$' ' -f2)
  
  if [ "$kibana_status" != "200" ]
  then
    echo "  Kibana not ready yet - retrying in 5 seconds..."
    sleep 5
  else
    echo "  Done"
  fi
done

echo "Setting up Kibana objects"
curl $kibana_base_url/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2?overwrite=true \
  --silent \
  --header 'Content-Type: application/json' \
  --header 'kbn-xsrf: true' \
  --data @bootstrap-data/kibana/index-patterns/tyk-analytics.json \
  > /dev/null
curl $kibana_base_url/api/saved_objects/visualization/407e91c0-8168-11ea-9323-293461ad91e5?overwrite=true \
  --silent \
  --header 'Content-Type: application/json' \
  --header 'kbn-xsrf: true' \
  --data @bootstrap-data/kibana/visualizations/request-count-by-time.json \
  > /dev/null
echo "  Done"

echo "Making test call to Bootstrap API"
bootstrap_api_status=$(curl -I $gateway_base_url/bootstrap-api/get 2>/dev/null | head -n 1 | cut -d$' ' -f2)
if [ "$bootstrap_api_status" != "200" ]
then
  echo "  Failed"
else
  echo "  Done"
fi

echo "Bootstrap complete"

cat <<EOF

            #####################                  ####               
            #####################                  ####               
                    #####                          ####               
  /////////         #####    ((.            (((    ####          (((  
  ///////////,      #####    ####         #####    ####       /####   
  ////////////      #####    ####         #####    ####      #####    
  ////////////      #####    ####         #####    ##############     
    //////////      #####    ####         #####    ##############     
                    #####    ####         #####    ####      ,####    
                    #####    ##################    ####        ####   
                    #####      ########## #####    ####         ####  
                                         #####                        
                             ################                         
                               ##########/                            

Dashboard
  URL      : $dashboard_base_url
             $dashboard_sso_base_url (SSO)
  Username : $dashboard_user_email
  Password : $dashboard_user_password

Portal
  URL      : $dashboard_base_url$portal_root_path
  Username : $portal_user_email
  Password : $portal_user_password

Gateway
  URL : $gateway_base_url
        $gateway_tls_base_url

Kibana
  URL : $kibana_base_url

EOF