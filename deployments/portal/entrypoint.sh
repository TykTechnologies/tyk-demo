#!/bin/bash
source /opt/common.sh

apt-get install -y jq

set -e

# Read the values from the mapped .context-data directory
dashboard_user_api_credentials=$(cat /.context-data/1-dashboard-user-1-api-key)
admin_user=$(cat /.context-data/1-dashboard-user-1-email)
admin_pass=$(cat /.context-data/1-dashboard-user-1-password)
org_id=$(cat /opt/tyk-dashboard/organization.json | jq -r .id)

/opt/portal/dev-portal --bootstrap --user=$admin_user --pass=$admin_pass --provider-name "TykPro@localhost" --provider-type=tyk-pro --provider-data="{\"URL\" : \"http://host.docker.internal:3000/\", \"Secret\":\"$dashboard_user_api_credentials\", \"OrgID\": \"$org_id\"}"

exec "$@"