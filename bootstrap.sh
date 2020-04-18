#!/bin/bash

DASHBOARD_BASE_URL="http://localhost:3000"
GATEWAY_BASE_URL="http://localhost:8080"
KIBANA_BASE_URL="http://localhost:5601"

echo "Getting Dashboard Admin API credentials"
DASHBOARD_ADMIN_API_CREDENTIALS=$(cat ./confs/tyk_analytics.conf | jq -r .admin_secret)
echo "  Dashboard Admin API Credentials: $DASHBOARD_ADMIN_API_CREDENTIALS"

echo "Creating Organisation"
ORGANISATION_ID=$(curl $DASHBOARD_BASE_URL/admin/organisations \
  --silent \
  --header "admin-auth: $DASHBOARD_ADMIN_API_CREDENTIALS" \
  --data @bootstrap-data/tyk-dashboard/organisation.json \
  | jq -r '.Meta')
echo "  Organisation Id: $ORGANISATION_ID"

echo "Creating Dashboard user"
DASHBOARD_USER_FIRST_NAME=$(jq -r '.first_name' bootstrap-data/tyk-dashboard/user.json)
DASHBOARD_USER_LAST_NAME=$(jq -r '.last_name' bootstrap-data/tyk-dashboard/user.json)
DASHBOARD_USER_EMAIL=$(jq -r '.email_address' bootstrap-data/tyk-dashboard/user.json)
DASHBOARD_USER=$(curl $DASHBOARD_BASE_URL/admin/users \
  --silent \
  --header "admin-auth: $DASHBOARD_ADMIN_API_CREDENTIALS" \
  --data-raw '{
      "first_name": "'$DASHBOARD_USER_FIRST_NAME'",
      "last_name": "'$DASHBOARD_USER_LAST_NAME'",
      "email_address": "'$DASHBOARD_USER_EMAIL'",
      "org_id": "'$ORGANISATION_ID'",
      "active": true,
      "user_permissions": {
          "IsAdmin": "admin",
          "ResetPassword": "admin"
      }
    }' \
    | jq -r '. | {api_key:.Message, id:.Meta.id}')
DASHBOARD_USER_ID=$(echo $DASHBOARD_USER | jq -r '.id')
DASHBOARD_USER_API_CREDENTIALS=$(echo $DASHBOARD_USER | jq -r '.api_key')
DASHBOARD_USER_PASSWORD=$(openssl rand -base64 12)
curl $DASHBOARD_BASE_URL/api/users/$DASHBOARD_USER_ID/actions/reset \
  --silent \
  --header "authorization: $DASHBOARD_USER_API_CREDENTIALS" \
  --data-raw '{
      "new_password":"'$DASHBOARD_USER_PASSWORD'",
      "user_permissions": { "IsAdmin": "admin" }
    }' \
  > /dev/null
echo "  Username: $DASHBOARD_USER_EMAIL"
echo "  Password: $DASHBOARD_USER_PASSWORD"
echo "  Dashboard API Credentials: $DASHBOARD_USER_API_CREDENTIALS"
echo "  ID: $DASHBOARD_USER_ID"

echo "Creating Portal home page"
curl $DASHBOARD_BASE_URL/api/portal/pages \
  --silent \
  --header "Authorization: $DASHBOARD_USER_API_CREDENTIALS" \
  --data '{"is_homepage": true, "template_name":"", "title":"Developer Portal Home", "slug":"/", "fields": {"JumboCTATitle": "Tyk Developer Portal", "SubHeading": "Sub Header", "JumboCTALink": "#cta", "JumboCTALinkTitle": "Your awesome APIs, hosted with Tyk!", "PanelOneContent": "Panel 1 content.", "PanelOneLink": "#panel1", "PanelOneLinkTitle": "Panel 1 Button", "PanelOneTitle": "Panel 1 Title", "PanelThereeContent": "", "PanelThreeContent": "Panel 3 content.", "PanelThreeLink": "#panel3", "PanelThreeLinkTitle": "Panel 3 Button", "PanelThreeTitle": "Panel 3 Title", "PanelTwoContent": "Panel 2 content.", "PanelTwoLink": "#panel2", "PanelTwoLinkTitle": "Panel 2 Button", "PanelTwoTitle": "Panel 2 Title"}}' \
  > /dev/null
echo "  Done"

echo "Synchronising APIs and Policies"
tyk-sync sync -d $DASHBOARD_BASE_URL -s $DASHBOARD_USER_API_CREDENTIALS -o $ORGANISATION_ID -p tyk-sync-data
echo "  Done"

echo "Making test API call"
curl $GATEWAY_BASE_URL:8080/bootstrap-api/get \
  --silent \
  > /dev/null
echo "  Done"

echo "Waiting for Kibana to be available (please be patient)"
kibana_status=""
while [[ $kibana_status != "200" ]]
do
  kibana_status=$(curl -I $KIBANA_BASE_URL/app/kibana 2>/dev/null | head -n 1 | cut -d$' ' -f2)
  if [[ $kibana_status != "200" ]]
  then
    echo "  Kibana not ready yet, waiting 5 seconds to try again"
    sleep 5
  fi
done
echo "  Done"

echo "Setting up Kibana objects"
curl $KIBANA_BASE_URL/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2?overwrite=true \
  --silent \
  --header 'Content-Type: application/json' \
  --header 'kbn-xsrf: true' \
  --data @bootstrap-data/kibana/index-patterns/tyk-analytics.json \
  > /dev/null
curl $KIBANA_BASE_URL:5601/api/saved_objects/visualization/407e91c0-8168-11ea-9323-293461ad91e5?overwrite=true \
  --silent \
  --header 'Content-Type: application/json' \
  --header 'kbn-xsrf: true' \
  --data @bootstrap-data/kibana/visualizations/requests-in-last-30-minutes.json \
  > /dev/null

echo "--------------------------------------"
echo "Bootstrap complete"
echo "Dashboard login information"
echo "  Dashboard URL: $DASHBOARD_BASE_URL"
echo "  Username: $DASHBOARD_USER_EMAIL"
echo "  Password: $DASHBOARD_USER_PASSWORD"