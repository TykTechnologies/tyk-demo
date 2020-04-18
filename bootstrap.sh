#!/bin/bash

dashboard_base_url="http://localhost:3000"
gateway_base_url="http://localhost:8080"
kibana_base_url="http://localhost:5601"

echo "Getting Dashboard Admin API credentials"
dashboard_admin_api_credentials=$(cat ./confs/tyk_analytics.conf | jq -r .admin_secret)
echo "  Dashboard Admin API Credentials: $dashboard_admin_api_credentials"

echo "Creating Organisation"
organisation_id=$(curl $dashboard_base_url/admin/organisations \
  --silent \
  --header "admin-auth: $dashboard_admin_api_credentials" \
  --data @bootstrap-data/tyk-dashboard/organisation.json \
  | jq -r '.Meta')
echo "  Organisation Id: $organisation_id"

echo "Creating Dashboard user"
dashboard_user_first_name=$(jq -r '.first_name' bootstrap-data/tyk-dashboard/user.json)
dashboard_user_last_name=$(jq -r '.last_name' bootstrap-data/tyk-dashboard/user.json)
dashboard_user_email=$(jq -r '.email_address' bootstrap-data/tyk-dashboard/user.json)
dashboard_user=$(curl $dashboard_base_url/admin/users \
  --silent \
  --header "admin-auth: $dashboard_admin_api_credentials" \
  --data-raw '{
      "first_name": "'$dashboard_user_first_name'",
      "last_name": "'$dashboard_user_last_name'",
      "email_address": "'$dashboard_user_email'",
      "org_id": "'$organisation_id'",
      "active": true,
      "user_permissions": {
          "IsAdmin": "admin",
          "ResetPassword": "admin"
      }
    }' \
    | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard_user_id=$(echo $dashboard_user | jq -r '.id')
dashboard_user_api_credentials=$(echo $dashboard_user | jq -r '.api_key')
dashboard_user_password=$(openssl rand -base64 12)
curl $dashboard_base_url/api/users/$dashboard_user_id/actions/reset \
  --silent \
  --header "authorization: $dashboard_user_api_credentials" \
  --data-raw '{
      "new_password":"'$dashboard_user_password'",
      "user_permissions": { "IsAdmin": "admin" }
    }' \
  > /dev/null
echo "  Username: $dashboard_user_email"
echo "  Password: $dashboard_user_password"
echo "  Dashboard API Credentials: $dashboard_user_api_credentials"
echo "  ID: $dashboard_user_id"

echo "Creating Portal home page"
curl $dashboard_base_url/api/portal/pages \
  --silent \
  --header "Authorization: $dashboard_user_api_credentials" \
  --data '{"is_homepage": true, "template_name":"", "title":"Developer Portal Home", "slug":"/", "fields": {"JumboCTATitle": "Tyk Developer Portal", "SubHeading": "Sub Header", "JumboCTALink": "#cta", "JumboCTALinkTitle": "Your awesome APIs, hosted with Tyk!", "PanelOneContent": "Panel 1 content.", "PanelOneLink": "#panel1", "PanelOneLinkTitle": "Panel 1 Button", "PanelOneTitle": "Panel 1 Title", "PanelThereeContent": "", "PanelThreeContent": "Panel 3 content.", "PanelThreeLink": "#panel3", "PanelThreeLinkTitle": "Panel 3 Button", "PanelThreeTitle": "Panel 3 Title", "PanelTwoContent": "Panel 2 content.", "PanelTwoLink": "#panel2", "PanelTwoLinkTitle": "Panel 2 Button", "PanelTwoTitle": "Panel 2 Title"}}' \
  > /dev/null
echo "  Done"

echo "Synchronising APIs and Policies"
tyk-sync sync -d $dashboard_base_url -s $dashboard_user_api_credentials -o $organisation_id -p tyk-sync-data
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
  --data @bootstrap-data/kibana/visualizations/requests-in-last-30-minutes.json \
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

echo "--------------------------------------"
echo "Bootstrap complete"
echo "Dashboard login information"
echo "  Dashboard URL: $dashboard_base_url"
echo "  Username: $dashboard_user_email"
echo "  Password: $dashboard_user_password"