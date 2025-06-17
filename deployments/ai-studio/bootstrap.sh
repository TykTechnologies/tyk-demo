#!/bin/bash

# This script generates and prints the docker compose command for the ai-studio deployment, with basic logging.

source scripts/common.sh
deployment="AI Studio"
log_start_deployment
bootstrap_progress

log_message "Generating docker compose command for ai-studio deployment..."
$(generate_docker_compose_command) up -d --no-deps --force-recreate 1>/dev/null 2>>logs/bootstrap.log
log_message "Done."
log_end_deployment

echo -e "\nLog in to Tyk AI Studio with:\n  Username: dev@tyk.io\n  Password: T0pSecR3t!\n"
