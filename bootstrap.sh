#!/bin/bash

dashboard_base_url="http://localhost:3000"
dashboard_sso_base_url="http://localhost:3001"
gateway_base_url="http://localhost:8080"
gateway_tls_base_url="https://localhost:8081"
kibana_base_url="http://localhost:5601"
identity_broker_base_url="http://localhost:3010"
jenkins_base_url="http://localhost:8070"
e2_dashboard_base_url="http://localhost:3002"
e2_gateway_base_url="http://localhost:8085"

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
organisation_id=$(curl $dashboard_base_url/admin/organisations/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/organisation.json \
  | jq -r '.Meta')
echo $organisation_id > .organisation-id
echo "  Organisation Id: $organisation_id"

echo "Importing Organisation for environment 2"
curl $e2_dashboard_base_url/admin/organisations/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/organisation.json \
  > /dev/null
echo "  Done"

echo "Creating Dashboard user"
dashboard_user_email=$(jq -r '.email_address' bootstrap-data/tyk-dashboard/dashboard-user.json)
dashboard_user_api_response=$(curl $dashboard_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/dashboard-user.json \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard_user_id=$(echo $dashboard_user_api_response | jq -r '.id')
dashboard_user_api_credentials=$(echo $dashboard_user_api_response | jq -r '.api_key')
dashboard_user_password=$(jq -r '.password' bootstrap-data/tyk-dashboard/dashboard-user.json)
curl $dashboard_base_url/api/users/$dashboard_user_id/actions/reset -s \
  -H "authorization: $dashboard_user_api_credentials" \
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

echo "Creating Dashboard user for environment 2"
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
    }' \
  > /dev/null
echo "  Dashboard API Credentials: $e2_dashboard_user_api_credentials"

echo "Creating Dashboard User Groups"
curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/usergroup-readonly.json \
  > /dev/null
curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/usergroup-default.json \
  > /dev/null
curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/usergroup-admin.json \
  > /dev/null
user_group_data=$(curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials")
user_group_readonly_id=$(echo $user_group_data | jq -r .groups[0].id)
user_group_default_id=$(echo $user_group_data | jq -r .groups[1].id)
user_group_admin_id=$(echo $user_group_data | jq -r .groups[2].id)
echo "  Done"

echo "Creating Webhooks"
curl $dashboard_base_url/api/hooks -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/webhook-webhook-receiver-api-post.json \
  > /dev/null
echo "  Done"

echo "Creating Portal default settings"
curl $dashboard_base_url/api/portal/catalogue -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d '{"org_id": "'$organisation_id'"}' \
  > /dev/null
curl $dashboard_base_url/api/portal/configuration -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d "{}" \
  > /dev/null
echo "  Done"

echo "Creating Portal home page"
curl $dashboard_base_url/api/portal/pages -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @bootstrap-data/tyk-dashboard/portal-home-page.json \
  > /dev/null
echo "  Done"

echo "Creating Portal user"
portal_user_email=$(jq -r '.email' bootstrap-data/tyk-dashboard/portal-user.json)
portal_user_password=$(openssl rand -base64 12)
curl $dashboard_base_url/api/portal/developers -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d '{
      "email": "'$portal_user_email'",
      "password": "'$portal_user_password'",
      "org_id": "'$organisation_id'"
    }' \
  > /dev/null
echo "  Done"

echo "Synchronising APIs and Policies"
docker run --rm \
  --network tyk-pro-docker-demo-extended_tyk \
  -v $(pwd)/data/tyk-sync:/opt/tyk-sync/data \
  tykio/tyk-sync:v1.1.0 \
  sync -d http://tyk-dashboard:3000 -s $dashboard_user_api_credentials -o $organisation_id -p data \
  > /dev/null
echo "  Done"

echo "Creating Identity Broker Profiles"
identity_broker_api_credentials=$(cat ./volumes/tyk-identity-broker/tib.conf | jq -r .Secret)
identity_broker_profile_tyk_dashboard_data=$(cat ./bootstrap-data/tyk-identity-broker/profile-tyk-dashboard.json | \
  sed 's/DASHBOARD_USER_API_CREDENTIALS/'"$dashboard_user_api_credentials"'/' | \
  sed 's/DASHBOARD_USER_GROUP_DEFAULT/'"$user_group_default_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_READONLY/'"$user_group_readonly_id"'/' | \
  sed 's/DASHBOARD_USER_GROUP_ADMIN/'"$user_group_admin_id"'/')
curl $identity_broker_base_url/api/profiles/tyk-dashboard -s \
  -H "Authorization: $identity_broker_api_credentials" \
  -d "$(echo $identity_broker_profile_tyk_dashboard_data)" \
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
curl $kibana_base_url/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2?overwrite=true -s \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @bootstrap-data/kibana/index-patterns/tyk-analytics.json \
  > /dev/null
curl $kibana_base_url/api/saved_objects/visualization/407e91c0-8168-11ea-9323-293461ad91e5?overwrite=true -s \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d @bootstrap-data/kibana/visualizations/request-count-by-time.json \
  > /dev/null
echo "  Done"

echo "Getting Jenkins admin password"
jenkins_admin_password=$(docker-compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
echo "  Done"

echo "Making Jenkins CLI available"
docker-compose exec \
  jenkins \
  curl -L -o /var/jenkins_home/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar \
  > /dev/null
echo "  Done"

echo "Importing custom keys"
gateway_admin_api_credentials=$(cat ./volumes/tyk-gateway/tyk.conf | jq -r .secret)
curl $gateway_base_url/tyk/keys/auth_key -s \
  -H "x-tyk-authorization: $gateway_admin_api_credentials" \
  -d @./bootstrap-data/tyk-gateway/auth-key.json \
  > /dev/null
curl $gateway_base_url/tyk/keys/ratelimit_key -s \
  -H "x-tyk-authorization: $gateway_admin_api_credentials" \
  -d @./bootstrap-data/tyk-gateway/rate-limit-key.json \
  > /dev/null
curl $gateway_base_url/tyk/keys/throttle_key -s \
  -H "x-tyk-authorization: $gateway_admin_api_credentials" \
  -d @./bootstrap-data/tyk-gateway/throttle-key.json \
  > /dev/null
curl $gateway_base_url/tyk/keys/quota_key -s \
  -H "x-tyk-authorization: $gateway_admin_api_credentials" \
  -d @./bootstrap-data/tyk-gateway/quota-key.json \
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
       URL : $dashboard_base_url
             $dashboard_sso_base_url (SSO)
             $e2_dashboard_base_url (Environment 2)
  Username : $dashboard_user_email
  Password : $dashboard_user_password

    Portal
       URL : $dashboard_base_url$portal_root_path
  Username : $portal_user_email
  Password : $portal_user_password

   Gateway
       URL : $gateway_base_url
             $gateway_tls_base_url
             $e2_gateway_base_url (Environment 2)

    Kibana
       URL : $kibana_base_url

   Jenkins
       URL : $jenkins_base_url
  Password : $jenkins_admin_password

EOF