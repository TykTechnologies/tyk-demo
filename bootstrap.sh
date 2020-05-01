#!/bin/bash

dashboard_base_url="http://localhost:3000"
gateway_base_url="http://localhost:8080"

echo "Making scripts executable"
chmod +x dump.sh
chmod +x sync.sh
chmod +x publish.sh
chmod +x update.sh
chmod +x add-gateway.sh
chmod +x bootstrap-e2.sh
chmod +x bootstrap-jenkins.sh
chmod +x bootstrap-kibana.sh
chmod +x bootstrap-zipkin.sh
chmod +x bootstrap-graphite.sh
chmod +x bootstrap-sso.sh
chmod +x bootstrap-tls.sh
echo "  Done"

echo "Creating directory for context data"
mkdir -p .context-data
echo "  Done"

echo "Getting Dashboard configuration"
dashboard_admin_api_credentials=$(cat ./volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
portal_root_path=$(cat ./volumes/tyk-dashboard/tyk_analytics.conf | jq -r .host_config.portal_root_path)
echo "  Dashboard Admin API Credentials: $dashboard_admin_api_credentials"
echo "  Portal Root Path: $portal_root_path"

echo "Waiting for Dashboard API to be ready"
dashboard_status=""
while [ "$dashboard_status" != "200" ]
do
  dashboard_status=$(curl -I $dashboard_base_url/admin/organisations -H "admin-auth: $dashboard_admin_api_credentials" 2>/dev/null | head -n 1 | cut -d$' ' -f2)
  
  if [ "$dashboard_status" != "200" ]
  then
    sleep 1
  fi
done
echo "  Done"

echo "Importing organisation"
organisation_id=$(curl $dashboard_base_url/admin/organisations/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/organisation.json \
  | jq -r '.Meta')
echo $organisation_id > .context-data/organisation-id
echo "  Organisation Id: $organisation_id"

echo "Creating Dashboard user"
dashboard_user_email=$(jq -r '.email_address' bootstrap-data/tyk-dashboard/dashboard-user.json)
dashboard_user_password=$(jq -r '.password' bootstrap-data/tyk-dashboard/dashboard-user.json)
dashboard_user_api_response=$(curl $dashboard_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/dashboard-user.json \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard_user_id=$(echo $dashboard_user_api_response | jq -r '.id')
dashboard_user_api_credentials=$(echo $dashboard_user_api_response | jq -r '.api_key')
curl $dashboard_base_url/api/users/$dashboard_user_id/actions/reset -s \
  -H "authorization: $dashboard_user_api_credentials" \
  --data-raw '{
      "new_password":"'$dashboard_user_password'",
      "user_permissions": { "IsAdmin": "admin" }
    }' > /dev/null
echo $dashboard_user_api_credentials > .context-data/dashboard-user-api-credentials
echo "  Username: $dashboard_user_email"
echo "  Password: $dashboard_user_password"
echo "  Dashboard API Credentials: $dashboard_user_api_credentials"
echo "  ID: $dashboard_user_id"

echo "Creating Dashboard user groups"
curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/usergroup-readonly.json > /dev/null
curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/usergroup-default.json > /dev/null
curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/usergroup-admin.json > /dev/null
user_group_data=$(curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials")
user_group_readonly_id=$(echo $user_group_data | jq -r .groups[0].id)
user_group_default_id=$(echo $user_group_data | jq -r .groups[1].id)
user_group_admin_id=$(echo $user_group_data | jq -r .groups[2].id)
echo $user_group_readonly_id > .context-data/user_group_readonly_id
echo $user_group_default_id > .context-data/user_group_default_id
echo $user_group_admin_id > .context-data/user_group_admin_id
echo "  Done"

echo "Creating webhooks"
curl $dashboard_base_url/api/hooks -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/webhook-webhook-receiver-api-post.json > /dev/null
echo "  Done"

echo "Synchronising APIs and policies"
source sync.sh > /dev/null
echo "  Done"

echo "Creating Portal default settings"
curl $dashboard_base_url/api/portal/configuration -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d "{}" > /dev/null
catalogue_id=$(curl $dashboard_base_url/api/portal/catalogue -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d '{"org_id": "'$organisation_id'"}' \
  | jq -r '.Message')
echo "  Done"

echo "Creating Portal home page"
curl $dashboard_base_url/api/portal/pages -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/portal-home-page.json > /dev/null
echo "  Done"

echo "Creating Portal user"
portal_user_email=$(jq -r '.email' bootstrap-data/tyk-dashboard/portal-user.json)
portal_user_password=$(jq -r '.password' bootstrap-data/tyk-dashboard/portal-user.json)
curl $dashboard_base_url/api/portal/developers -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d '{
      "email": "'$portal_user_email'",
      "password": "'$portal_user_password'",
      "org_id": "'$organisation_id'"
    }' > /dev/null
echo "  Done"

echo "Creating catalogue"
policies=$(curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials")
documentation_swagger_petstore_id=$(curl $dashboard_base_url/api/portal/documentation -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  --data-raw '{
      "api_id":"",
      "doc_type":"swagger",
      "documentation":"'$(cat bootstrap-data/tyk-dashboard/documentation-swagger-petstore.json | base64)'"
    }' \
  | jq -r '.Message')
policies_swagger_petstore_id=$(echo $policies | jq -r '.Data[] | select(.name=="Swagger Petstore Policy") | .id')
catalogue_data=$(cat ./bootstrap-data/tyk-dashboard/catalogue.json | \
  sed 's/CATALOGUE_ID/'"$catalogue_id"'/' | \
  sed 's/ORGANISATION_ID/'"$organisation_id"'/' | \
  sed 's/CATALOGUE_SWAGGER_PETSTORE_POLICY_ID/'"$policies_swagger_petstore_id"'/' | \
  sed 's/CATALOGUE_SWAGGER_PETSTORE_DOCUMENTATION_ID/'"$documentation_swagger_petstore_id"'/')
curl $dashboard_base_url/api/portal/catalogue -X 'PUT' -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d "$(echo $catalogue_data)" > /dev/null
echo "  Done"

echo "Waiting for Gateway API to be ready"
gateway_api_credentials=$(cat ./volumes/tyk-gateway/tyk.conf | jq -r .secret)
gateway_status=""
while [ "$gateway_status" != "200" ]
do
  gateway_status=$(curl $gateway_base_url/tyk/keys/api_key_write_test -s -o /dev/null -w '%{http_code}' -H "x-tyk-authorization: $gateway_api_credentials" -d @./bootstrap-data/tyk-gateway/auth-key.json)
  if [ "$gateway_status" != "200" ]
  then
    sleep 1
  fi
done
echo "  Done"

echo "Waiting for Gateway API to be ready"
gateway_api_credentials=$(cat ./volumes/tyk-gateway/tyk.conf | jq -r .secret)
gateway_status=""
while [ "$gateway_status" != "200" ]
do
  gateway_status=$(curl $gateway_base_url/tyk/keys/api_key_write_test -s -o /dev/null -w '%{http_code}' -H "x-tyk-authorization: $gateway_api_credentials" -d @./bootstrap-data/tyk-gateway/auth-key.json)
  if [ "$gateway_status" != "200" ]
  then
    sleep 1
  fi
done
echo "  Done"

echo "Importing custom keys"
curl $gateway_base_url/tyk/keys/auth_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @./bootstrap-data/tyk-gateway/auth-key.json > /dev/null
curl $gateway_base_url/tyk/keys/ratelimit_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @./bootstrap-data/tyk-gateway/rate-limit-key.json > /dev/null
curl $gateway_base_url/tyk/keys/throttle_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @./bootstrap-data/tyk-gateway/throttle-key.json > /dev/null
curl $gateway_base_url/tyk/keys/quota_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @./bootstrap-data/tyk-gateway/quota-key.json > /dev/null
echo "  Done"

echo "Checking Gateway functionality"
gateway_status=""
while [ "$gateway_status" != "200" ]
do
  gateway_status=$(curl -I $gateway_base_url/basic-open-api/get 2>/dev/null | head -n 1 | cut -d$' ' -f2)
  
  if [ "$gateway_status" != "200" ]
  then
    sleep 1
  fi
done
echo "  Done"

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
               URL : $dashboard_base_url
          Username : $dashboard_user_email
          Password : $dashboard_user_password
   API Credentials : $dashboard_user_api_credentials

            Portal
               URL : $dashboard_base_url$portal_root_path
          Username : $portal_user_email
          Password : $portal_user_password

           Gateway
               URL : $gateway_base_url

EOF