#!/bin/bash

echo "Getting Dashboard Admin API credentials"
DASHBOARD_ADMIN_API_CREDENTIALS=$(cat ./confs/tyk_analytics.conf | jq -r .admin_secret)
echo "  Dashboard Admin API Credentials: $DASHBOARD_ADMIN_API_CREDENTIALS"

echo "Creating Organisation"
ORGANISATION_ID=$(curl localhost:3000/admin/organisations \
  --silent \
  --header "admin-auth: $DASHBOARD_ADMIN_API_CREDENTIALS" \
  --data @bootstrap-data/tyk-dashboard/organisation.json \
  | jq -r '.Meta')
echo "  Organisation Id: $ORGANISATION_ID"

echo "Creating Dashboard user"
DASHBOARD_USER_FIRST_NAME=$(jq -r '.first_name' bootstrap-data/tyk-dashboard/user.json)
DASHBOARD_USER_LAST_NAME=$(jq -r '.last_name' bootstrap-data/tyk-dashboard/user.json)
DASHBOARD_USER_EMAIL=$(jq -r '.email_address' bootstrap-data/tyk-dashboard/user.json)
DASHBOARD_USER=$(curl localhost:3000/admin/users \
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
curl localhost:3000/api/users/$DASHBOARD_USER_ID/actions/reset \
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
curl localhost:3000/api/portal/pages \
  --silent \
  --header "Authorization: $DASHBOARD_USER_API_CREDENTIALS" \
  --data '{"is_homepage": true, "template_name":"", "title":"Developer Portal Home", "slug":"/", "fields": {"JumboCTATitle": "Tyk Developer Portal", "SubHeading": "Sub Header", "JumboCTALink": "#cta", "JumboCTALinkTitle": "Your awesome APIs, hosted with Tyk!", "PanelOneContent": "Panel 1 content.", "PanelOneLink": "#panel1", "PanelOneLinkTitle": "Panel 1 Button", "PanelOneTitle": "Panel 1 Title", "PanelThereeContent": "", "PanelThreeContent": "Panel 3 content.", "PanelThreeLink": "#panel3", "PanelThreeLinkTitle": "Panel 3 Button", "PanelThreeTitle": "Panel 3 Title", "PanelTwoContent": "Panel 2 content.", "PanelTwoLink": "#panel2", "PanelTwoLinkTitle": "Panel 2 Button", "PanelTwoTitle": "Panel 2 Title"}}' \
  > /dev/null
echo "  Done"

echo "Synchronising APIs and Policies"
tyk-sync sync -d http://localhost:3000 -s $DASHBOARD_USER_API_CREDENTIALS -o $ORGANISATION_ID -p tyk-sync-data
echo "  Done"

echo "Making test API call"
curl localhost:8080/bootstrap-api/get \
  --silent \
  > /dev/null
echo "  Done"

echo "Setting up Kibana objects"
curl --location --request POST 'http://localhost:5601/api/saved_objects/index-pattern/1208b8f0-815b-11ea-b0b2-c9a8a88fbfb2' \
--header 'Content-Type: application/json' \
--header 'kbn-xsrf: true' \
--header 'Content-Type: text/plain' \
--data-raw '{
    "attributes": {
        "title": "tyk_analytics*",
        "timeFieldName": "@timestamp",
        "fields": "[{\"name\":\"@timestamp\",\"type\":\"date\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"_id\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":false},{\"name\":\"_index\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":false},{\"name\":\"_score\",\"type\":\"number\",\"count\":0,\"scripted\":false,\"searchable\":false,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"_source\",\"type\":\"_source\",\"count\":0,\"scripted\":false,\"searchable\":false,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"_type\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":false},{\"name\":\"alias\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"alias.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"api_id\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"api_id.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"api_key\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"api_key.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"api_name\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"api_name.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"api_version\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"api_version.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"content_length\",\"type\":\"number\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"http_method\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"http_method.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"ip_address\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"ip_address.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"oauth_id\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"oauth_id.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"org_id\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"org_id.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"request_time_ms\",\"type\":\"number\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"request_uri\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"request_uri.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"request_uri_full\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"request_uri_full.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"response_code\",\"type\":\"number\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true},{\"name\":\"tags\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":false,\"readFromDocValues\":false},{\"name\":\"tags.keyword\",\"type\":\"string\",\"count\":0,\"scripted\":false,\"searchable\":true,\"aggregatable\":true,\"readFromDocValues\":true}]"
    }
}'

echo "--------------------------------------"
echo "Bootstrap complete"
echo "Dashboard login information"
echo "  Dashboard URL: http://localhost:3000"
echo "  Username: $DASHBOARD_USER_EMAIL"
echo "  Password: $DASHBOARD_USER_PASSWORD"