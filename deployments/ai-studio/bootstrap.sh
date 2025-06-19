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


echo -e "\033[2K 
▼ Tyk AI Studio
  ▽ AI Gateway
                    URL : http://localhost:9090
  ▽ UI
                    URL : http://localhost:3010
               Username : dev@tyk.io
               Password : T0pSecR3t!"