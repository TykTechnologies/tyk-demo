#!/bin/bash
source scripts/common.sh

# Get Tyk Dashboard API Access Credentials
dashboard_user_api_credentials=$(get_context_data "1" "dashboard-user" "1" "api-key")

DB='deployments/portal/volumes/database/portal.db'

# Read meta_data field from the SQLite table provider_configs
CONFIG=`sqlite3 $DB "select meta_data from provider_configs;"`

# Read the new secret
VALUE=$dashboard_user_api_credentials

# Pipe the config into JQ, replace the secret with the generated one
UPDATED_CONFIG=`echo $CONFIG | jq --arg value $VALUE '.Secret = $value'`

# UPDATE SQLite table for portal to re-connect to dashboard.
# Provider config for Tyk has an id of 1, hardcoding this value for now
sqlite3 $DB "update provider_configs SET meta_data='$UPDATED_CONFIG' WHERE id=1"
