#!/bin/bash

# This script generates and prints the docker compose command for the ai-studio deployment, with basic logging.

source scripts/common.sh
deployment="AI Studio"
log_start_deployment
bootstrap_progress

log_message "Removing AI Studio service"
# this is to allow the database to be reset in the next step
$(generate_docker_compose_command) rm -s -f -v tyk-ai-studio 1>>logs/bootstrap.log 2>&1
log_ok
bootstrap_progress

log_message "Resetting AI Studio database"
# this ensures that the AI Studio database is reset to a clean state on each bootstrap
cp deployments/ai-studio/data/tyk-ai-studio/ai-studio.db deployments/ai-studio/volumes/tyk-ai-studio/db
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to reset AI Studio database"
    exit 1
fi
log_ok
bootstrap_progress

log_message "Recreate AI Studio service..."
$(generate_docker_compose_command) up -d --no-deps 1>/dev/null 1>>logs/bootstrap.log 2>&1
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K 
▼ Tyk AI Studio
  ▽ AI Gateway
                    URL : http://localhost:9090
  ▽ AI Portal
                    URL : http://localhost:3011
               Username : dev@tyk.io
               Password : T0pSecR3t!"