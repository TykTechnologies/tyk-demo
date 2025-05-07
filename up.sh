#!/bin/bash

source scripts/common.sh

# Function to display help information
display_help() {
    echo "Usage: ./up.sh [OPTIONS] [DEPLOYMENTS]"
    echo
    echo "Brings up Tyk Demo deployment with optional configurations."
    echo
    echo "Deployments:"
    # Dynamically list available deployments - except tyk, as it is handled automatically
    for deployment in deployments/*; do
      if [ -d "$deployment" ]; then
        deployment_name=$(basename "$deployment")
        echo "  $deployment_name"
      fi
    done
    echo
    echo "Options:"
    echo "  --help                Display this help message"
    echo "  --persist-log         Persist log files between bootstraps"
    echo "  --hide-progress       Hide deployment progress meter"
    echo "  --skip-plugin-build   Skip building Go plugins (can also use --spb)"
    echo "  --skip-hostname-check Skip validation of hostnames in /etc/hosts"
    echo
    echo "Examples:"
    echo "  ./up.sh                       # Bring up default Tyk deployment"
    echo "  ./up.sh analytics-kibana      # Bring up Tyk deployment with an additional deployment (analytics-kibana)"
    echo "  ./up.sh tyk2 cicd             # Bring up Tyk deployment with two additionals deployments (tyk2 and cicd)"
    echo "  ./up.sh --help                # Show this help message"
    echo "  ./up.sh --persist-log         # Persist logs"
    echo "  ./up.sh --skip-hostname-check # Skip hostname validation"
}

# Check for help flag
if [[ "$1" == "--help" ]]; then
    display_help
    exit 0
fi

up_start_time=$(date +%s)

# persistence of log files is disabled by default, meaning the files are recreated between each bootstrap to prevent them from growing too large
# to enable persistence, use argument "persist-log" when running this script
persist_log=false

# hostname check is enabled by default
skip_hostname_check=false

# Reset bootstrap flags
# Remove hide_progress file to ensure bootstrap progress is displayed by default
rm .bootstrap/hide_progress 1>/dev/null 2>&1
# Remove skip_plugin_build file to ensure plugins are built by default
rm .bootstrap/skip_plugin_build 1>/dev/null 2>&1

echo "Bringing Tyk Demo deployment UP"

# check .env file exists
if [ ! -f .env ]; then
  echo "ERROR: Docker environment file missing. Review 'getting started' steps in README.md."
  exit 1
fi

# check that jq is available
command -v jq >/dev/null 2>&1 || { echo >&2 "ERROR: JQ is required, but it's not installed. Review 'getting started' steps in README.md."; exit 1; }

# make the context data directory
mkdir -p .context-data 1> /dev/null

# make the .bootstrap directory
mkdir -p .bootstrap 1> /dev/null

# make the logs directory
mkdir -p logs 1> /dev/null

# ensure Docker environment variables are correctly set before creating containers
# these allow for specialised deployments to be easily used, without having to manually set the environment variables
# this approach aims to avoid misconfiguration and issues related to that
if [[ "$*" == *instrumentation* ]]; then
  set_docker_environment_value "INSTRUMENTATION_ENABLED" "1"
else
  set_docker_environment_value "INSTRUMENTATION_ENABLED" "0"
fi

if [[ "$*" == *otel* ]]; then
  set_docker_environment_value "OPENTELEMETRY_ENABLED" "true"
else
  set_docker_environment_value "OPENTELEMETRY_ENABLED" "false"
fi

if [[ "$*" == *otel-jaeger* ]]; then
  set_docker_environment_value "OPENTELEMETRY_ENDPOINT" "jaeger-all-in-one:4317"
else
  set_docker_environment_value "OPENTELEMETRY_ENDPOINT" ""
fi

# set gateway image repo based on licence
# if the licence contains enterprise scopes, then the enterprise image is used
if check_licence_requires_enterprise "DASHBOARD_LICENCE"; then
  set_docker_environment_value "GATEWAY_IMAGE_REPO" "tyk-gateway-ee"
else
  set_docker_environment_value "GATEWAY_IMAGE_REPO" "tyk-gateway"
fi

# deployment lists
deployments_to_create=()
commands_to_process=()
available_deployments=(deployments/*)

# establish list of existing deployments to resume
echo "Deployments to resume:"
if [[ -s .bootstrap/bootstrapped_deployments ]]; then
  while read existing_deployment; do
    echo "  $existing_deployment"
  done < .bootstrap/bootstrapped_deployments

  echo "Note: Resumed deployments are not rebootstrapped - they use their existing volumes"
  echo "Tip: To rebootstrap deployments, you must first remove them using the down.sh script"
else
  echo "  None"
  # tyk is always added to the deployment list when no deployments exist
  deployments_to_create+=("tyk")
fi

# parse script arguments to establish lists of new deployments to create, and commands to process
for argument in "$@"; do
  # "tyk" deployment is handled automatically, so ignore it and continue to the next argument
  [ "$argument" == "tyk" ] && continue

  # check if argument refers to a deployment
  if [ -d "deployments/$argument" ]; then
    # skip existing deployments, to avoid rebootstrapping
    [ -f ".bootstrap/bootstrapped_deployments" ] && [ ! -z $(grep "$argument" ".bootstrap/bootstrapped_deployments") ] && break
    # otherwise, queue deployment to be created
    deployments_to_create+=("$argument")
  else
    commands_to_process+=("$argument")
  fi
done

# display deployments to bootstrap
echo "Deployments to create:"
if (( ${#deployments_to_create[@]} != 0 )); then
  for deployment in "${deployments_to_create[@]}"; do
    echo "$deployment" >> .bootstrap/bootstrapped_deployments
    echo "  $deployment"
  done
else
  echo "  None"
fi

# display commands to process
echo "Commands to process:"
if (( ${#commands_to_process[@]} != 0 )); then
  for command in "${commands_to_process[@]}"; do    
    case $command in
      "--persist-log")
        echo "  persist-log: Logs will be persisted"
        persist_log=true
        ;;
      "--hide-progress")
        echo "  hide-progress: Deployment progress meter will not be shown"
        touch .bootstrap/hide_progress
        ;;
      "--skip-plugin-build" | "--spb")
        echo "  skip-plugin-build: Go plugins will not be built"
        touch .bootstrap/skip_plugin_build
        ;;
      "--skip-hostname-check")
        echo "  skip-hostname-check: Hostname validation will be skipped"
        skip_hostname_check=true
        ;;
      *) 
        echo "Invalid argument: $command"
        display_help
        exit 1
        ;; 
    esac
  done
else
  echo "  None"
fi

# check hostnames exist (unless skipped)
if [ "$skip_hostname_check" = false ]; then
  if [ ! -f "deployments/tyk/data/misc/hosts/hosts.list" ]; then
    echo "ERROR: File deployments/tyk/data/misc/hosts/hosts.list not found."
    exit 1
  fi

  while IFS= read -r hostname || [ -n "$hostname" ]; do
    if ! grep -q "$hostname" /etc/hosts; then
      echo "ERROR: /etc/hosts is missing entry for $hostname. Run this command to update: sudo ./scripts/update-hosts.sh"
      echo "Note: You can skip this check by using the --skip-hostname-check option"
      exit 1
    fi
  done < "deployments/tyk/data/misc/hosts/hosts.list"
else
  echo "Warning: Hostname validation has been skipped. Ensure your hosts are correctly configured."
fi

# clear logs, if they are not persisted
if [ "$persist_log" = false ]; then
  prepare_bootstrap_log
fi

# log docker compose version
log_message "$(docker compose version)"

# bring the containers up
command_docker_compose="$(generate_docker_compose_command) up --quiet-pull --remove-orphans -d"
echo "Running docker compose command: $command_docker_compose"
eval $command_docker_compose; command_exit_code=$?
if [ "$command_exit_code" != 0 ]; then
  echo "Error occurred when using Docker Compose to bring containers up"
  exit 1
fi

# bootstrap the deployments
for deployment in "${deployments_to_create[@]}"; do
  eval "deployments/$deployment/bootstrap.sh"; bootstrap_exit_code=$?
  if [ "$bootstrap_exit_code" != 0 ]; then
    capture_container_logs $deployment
    # Generic error message for other issues
    echo "Error occurred during bootstrap of $deployment, when running deployments/$deployment/bootstrap.sh"
    echo "Log files can be found in the the logs directory"
    exit 1
  fi
done

up_end_time=$(date +%s)
up_elapsed_time=$((up_end_time - up_start_time))
up_minutes=$((up_elapsed_time / 60))
up_seconds=$((up_elapsed_time % 60))
if [ $up_minutes -gt 0 ]; then
    log_message "Elapsed time: $up_minutes minutes $up_seconds seconds"
else
    log_message "Elapsed time: $up_seconds seconds"
fi

# Confirm initialisation process is complete
printf "\nTyk Demo initialisation process completed"
printf "\n-----------------------------------------\n\n"
