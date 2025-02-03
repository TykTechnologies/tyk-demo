#!/bin/bash

source scripts/common.sh

up_start_time=$(date +%s)

# persistence of log files is disabled by default, meaning the files are recreated between each bootstrap to prevent them from growing too large
# to enable persistence, use argument "persist-log" when running this script
persist_log=false

# the hide_progress file determines whether the bootstrap_progress function creates output
# this is preferable in CICD tests as it prevent pollution of the logs with these messages which are user focussed
# use the "hide-progress" flag to enable this
rm .bootstrap/hide_progress 1>/dev/null 2>&1

echo "Bringing Tyk Demo deployment UP"

# check .env file exists
if [ ! -f .env ]; then
  echo "ERROR: Docker environment file missing. Review 'getting started' steps in README.md."
  exit 1
fi

# check hostnames exist
for i in "${tyk_demo_hostnames[@]}"; do
  if ! grep -q "$i" /etc/hosts; then
    echo "ERROR: /etc/hosts is missing entry for $i. Run this command to update: sudo ./scripts/update-hosts.sh"
    exit 1
  fi
done

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
if [[ "$*" == *tracing* ]]; then
  set_docker_environment_value "TRACING_ENABLED" "true"
else
  set_docker_environment_value "TRACING_ENABLED" "false"
fi

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
      "persist-log")
        echo "  persist-log: Logs will be persisted"
        persist_log=true
        ;;
      "hide-progress")
        echo "  hide-progress: Deployment progress meter will not be shown"
        touch .bootstrap/hide_progress
        ;;
      *) 
        echo "Command \"$command\" is unknown, ignoring."
        ;; 
    esac
  done
else
  echo "  None"
fi

# clear logs, if they are not persisted
if [ "$persist_log" = false ]; then
  echo -n > logs/bootstrap.log
  rm logs/container-*.log 1>/dev/null 2>&1 # there can be multiple container logs
  # test.log file is not cleared, as it is responsibilty of the test scripts
fi

# log docker compose version
log_message "$(docker compose version)"

# bring the containers up
command_docker_compose="$(generate_docker_compose_command) up --quiet-pull --remove-orphans -d"
echo "Running docker compose command: $command_docker_compose"
eval $command_docker_compose
if [ "$?" != 0 ]; then
  echo "Error occurred when using Docker Compose to bring containers up"
  exit 1
fi

# bootstrap the deployments
for deployment in "${deployments_to_create[@]}"; do
  eval "deployments/$deployment/bootstrap.sh"
  if [ "$?" != 0 ]; then
    capture_container_logs $deployment
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
