#!/bin/bash

echo "Begin standard Tyk bootstrap" >bootstrap.log

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping Tyk ${dots// /.} \r"
}

bootstrap_progress

dashboard_base_url="http://localhost:3000"
gateway_base_url="http://localhost:8080"

echo "Check for instrumentaton misconfiguration" >>bootstrap.log
# Prevent instrumentation being enabled without the Graphite service being available
instrumentation_service=$(docker-compose -f docker-compose.yml -f instrumentation/docker-compose.yml ps | grep "graphite")
instrumentation_setting=$(grep "INSTRUMENTATION_ENABLED" .env)
instrumentation_setting_enabled="INSTRUMENTATION_ENABLED=1"
instrumentation_setting_disabled="INSTRUMENTATION_ENABLED=0"
if [[ "${#instrumentation_service}" -eq "0" ]] && [[ $instrumentation_setting == $instrumentation_setting_enabled ]]
then
  echo "Setting instrumentation flag to 0" >>bootstrap.log
  sed -i.bak 's/'"$instrumentation_setting_enabled"'/'"$instrumentation_setting_disabled"'/g' ./.env
  rm .env.bak
  docker-compose up --force-recreate -d 2>/dev/null
fi
bootstrap_progress

echo "Check for tracing misconfiguration" >>bootstrap.log
# Prevent tracking being enabled without the Zipkin service being available
tracing_service=$(docker-compose -f docker-compose.yml -f tracing/docker-compose.yml ps --services | grep "zipkin")
tracing_setting=$(grep "TRACING_ENABLED" .env)
tracing_setting_enabled="TRACING_ENABLED=true"
tracing_setting_disabled="TRACING_ENABLED=false"
if [ $tracing_service != "zipkin" ] && [[ $tracing_setting == $tracing_setting_enabled ]]
then
  echo "Setting tracing flag to false" >>bootstrap.log
  sed -i.bak 's/'"$tracing_setting_enabled"'/'"$tracing_setting_disabled"'/g' ./.env
  rm .env.bak
  docker-compose restart 2>/dev/null
fi
bootstrap_progress

echo "Making scripts executable" >>bootstrap.log
chmod +x `ls */*.sh` >>bootstrap.log
bootstrap_progress

echo "Creating directory for context data" >>bootstrap.log
mkdir -p .context-data >>bootstrap.log
bootstrap_progress

echo "Getting Dashboard configuration" >>bootstrap.log
dashboard_admin_api_credentials=$(cat tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret 2>>bootstrap.log)
portal_root_path=$(cat tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .host_config.portal_root_path 2>>bootstrap.log)
bootstrap_progress

echo "Waiting for Dashboard API to be ready" >>bootstrap.log
dashboard_status=""
while [ "$dashboard_status" != "200" ]
do
  dashboard_status=$(curl -I $dashboard_base_url/admin/organisations -H "admin-auth: $dashboard_admin_api_credentials" -s 2>>bootstrap.log | head -n 1 | cut -d$' ' -f2)
  if [ "$dashboard_status" != "200" ]
  then
    echo "$dashboard_status" >>bootstrap.log
    sleep 1
  fi
  bootstrap_progress
done

echo "Importing organisation" >> bootstrap.log
organisation_id=$(curl $dashboard_base_url/admin/organisations/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @tyk/data/tyk-dashboard/organisation.json 2>>bootstrap.log\
  | jq -r '.Meta')
echo $organisation_id > .context-data/organisation-id
bootstrap_progress

echo "Import data" >>bootstrap.log
./scripts/import.sh
bootstrap_progress

echo "Creating Dashboard user" >>bootstrap.log
dashboard_user_email=$(jq -r '.email_address' tyk/data/tyk-dashboard/dashboard-user.json)
dashboard_user_password=$(jq -r '.password' tyk/data/tyk-dashboard/dashboard-user.json)
dashboard_user_api_response=$(curl $dashboard_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @tyk/data/tyk-dashboard/dashboard-user.json 2>>bootstrap.log \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard_user_id=$(echo $dashboard_user_api_response | jq -r '.id')
dashboard_user_api_credentials=$(echo $dashboard_user_api_response | jq -r '.api_key')
curl $dashboard_base_url/api/users/$dashboard_user_id/actions/reset -s \
  -H "authorization: $dashboard_user_api_credentials" \
  --data-raw '{
      "new_password":"'$dashboard_user_password'",
      "user_permissions": { "IsAdmin": "admin" }
    }' >>bootstrap.log
bootstrap_progress

echo "Creating Dashboard user groups" >> bootstrap.log
curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @tyk/data/tyk-dashboard/usergroup-readonly.json >>bootstrap.log
curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @tyk/data/tyk-dashboard/usergroup-default.json >>bootstrap.log
curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @tyk/data/tyk-dashboard/usergroup-admin.json >>bootstrap.log
user_group_data=$(curl $dashboard_base_url/api/usergroups -s \
  -H "Authorization: $dashboard_user_api_credentials" 2>>bootstrap.log)
echo $user_group_data | jq -r .groups[0].id > .context-data/user_group_readonly_id
echo $user_group_data | jq -r .groups[1].id > .context-data/user_group_default_id
echo $user_group_data | jq -r .groups[2].id > .context-data/user_group_admin_id
bootstrap_progress

echo "Creating webhooks" >>bootstrap.log
curl $dashboard_base_url/api/hooks -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @tyk/data/tyk-dashboard/webhook-webhook-receiver-api-post.json >>bootstrap.log
bootstrap_progress

echo "Creating Portal default settings" >>bootstrap.log
curl $dashboard_base_url/api/portal/configuration -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d "{}" >>bootstrap.log
catalogue_id=$(curl $dashboard_base_url/api/portal/catalogue -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d '{"org_id": "'$organisation_id'"}' 2>>bootstrap.log \
  | jq -r '.Message')
bootstrap_progress

echo "Creating Portal home page" >> bootstrap.log
curl $dashboard_base_url/api/portal/pages -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d @tyk/data/tyk-dashboard/portal-home-page.json >>bootstrap.log
bootstrap_progress

echo "Creating Portal user" >>bootstrap.log
portal_user_email=$(jq -r '.email' tyk/data/tyk-dashboard/portal-user.json)
portal_user_password=$(jq -r '.password' tyk/data/tyk-dashboard/portal-user.json)
curl $dashboard_base_url/api/portal/developers -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d '{
      "email": "'$portal_user_email'",
      "password": "'$portal_user_password'",
      "org_id": "'$organisation_id'"
    }' >>bootstrap.log
bootstrap_progress

echo "Creating catalogue" >>bootstrap.log
policies=$(curl $dashboard_base_url/api/portal/policies?p=-1 -s \
  -H "Authorization:$dashboard_user_api_credentials" 2>>bootstrap.log)
documentation_swagger_petstore_id=$(curl $dashboard_base_url/api/portal/documentation -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  --data-raw '{
      "api_id":"",
      "doc_type":"swagger",
      "documentation":"'$(cat tyk/data/tyk-dashboard/documentation-swagger-petstore.json | base64)'"
    }' 2>>bootstrap.log \
  | jq -r '.Message')
policies_swagger_petstore_id=$(echo $policies | jq -r '.Data[] | select(.name=="Swagger Petstore Policy") | .id')
catalogue_data=$(cat tyk/data/tyk-dashboard/catalogue.json | \
  sed 's/CATALOGUE_ID/'"$catalogue_id"'/' | \
  sed 's/ORGANISATION_ID/'"$organisation_id"'/' | \
  sed 's/CATALOGUE_SWAGGER_PETSTORE_POLICY_ID/'"$policies_swagger_petstore_id"'/' | \
  sed 's/CATALOGUE_SWAGGER_PETSTORE_DOCUMENTATION_ID/'"$documentation_swagger_petstore_id"'/')
curl $dashboard_base_url/api/portal/catalogue -X 'PUT' -s \
  -H "Authorization: $dashboard_user_api_credentials" \
  -d "$(echo $catalogue_data)" >>bootstrap.log
bootstrap_progress

echo "Waiting for Gateway API to be ready" >>bootstrap.log
gateway_api_credentials=$(cat tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
gateway_status=""
while [ "$gateway_status" != "200" ]
do
  gateway_status=$(curl $gateway_base_url/tyk/keys/api_key_write_test -s -o /dev/null -w "%{http_code}" -H "x-tyk-authorization: $gateway_api_credentials" -d @tyk/data/tyk-gateway/auth-key.json 2>>bootstrap.log)

  if [ "$gateway_status" != "200" ]
  then
    echo "Gateway status:$gateway_status" >>bootstrap.log
    sleep 1
  fi
  bootstrap_progress
done

echo "Importing custom keys" >>bootstrap.log
curl $gateway_base_url/tyk/keys/auth_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @tyk/data/tyk-gateway/auth-key.json >>bootstrap.log
curl $gateway_base_url/tyk/keys/ratelimit_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @tyk/data/tyk-gateway/rate-limit-key.json >>bootstrap.log
curl $gateway_base_url/tyk/keys/throttle_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @tyk/data/tyk-gateway/throttle-key.json >>bootstrap.log
curl $gateway_base_url/tyk/keys/quota_key -s \
  -H "x-tyk-authorization: $gateway_api_credentials" \
  -d @tyk/data/tyk-gateway/quota-key.json >>bootstrap.log
bootstrap_progress

echo "Checking Gateway functionality" >>bootstrap.log
gateway_status=""
while [ "$gateway_status" != "200" ]
do
  gateway_status=$(curl -I -s $gateway_base_url/basic-open-api/get 2>>bootstrap.log | head -n 1 | cut -d$' ' -f2)
  if [ "$gateway_status" != "200" ]
  then
    echo "$gateway_status" >>bootstrap.log
    sleep 1
  fi
  bootstrap_progress
done

echo "End standard Tyk bootstrap" >>bootstrap.log

echo -e "\033[2K

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
"