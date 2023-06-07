#!/bin/bash

source scripts/common.sh

# persistence of bootstrap.log file is disabled by default, meaning the file is recreated between each bootstrap to prevent it from growing too large
# to enable persistence, use argument "persist-log" when running this script
persist_log=false

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

# check if docker compose version is v1.x
check_docker_compose_version

# ensure Docker environment variables are correctly set before creating containers
# these allow for tracing and instrumentation deployments to be easily used, without having to manually set the environment variables
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

# deployment lists
deployments_to_create=()
deployments_to_resume=()
commands_to_process=()
available_deployments=(deployments/*)

# establish list of existing deployments to resume
tyk_deployment_exists=false
echo "Deployments to resume:"
if [[ -s .bootstrap/bootstrapped_deployments ]]; then
  while read existing_deployment; do
    echo "  $existing_deployment"
    deployments_to_resume+=("$existing_deployment")
    if [ "$existing_deployment" = "tyk" ]; then
      tyk_deployment_exists=true
    fi
  done < .bootstrap/bootstrapped_deployments

  echo "Note: Resumed deployments are not rebootstrapped - they use the existing volumes"
  echo "Tip: To rebootstrap deployments, you must first remove them using the down.sh script"
else
  echo "  None"
fi

# add tyk to deployment list if it doesn't already exist
if [ "$tyk_deployment_exists" = false ]; then
  deployments_to_create+=("tyk")
fi

# parse script arguments to establish lists of new deployments to create, and commands to process
for argument in "$@"; do
  # "tyk" deployment is handled automatically, so ignore it and continue to the next argument
  [ "$argument" == "tyk" ] && continue

  # check if argument refers to a deployment
  if [ -d "deployments/$argument" ]; then
    # skip existing deployments, to avoid rebootstrapping
    [ ! -z $(grep "$argument" ".bootstrap/bootstrapped_deployments") ] && break
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
  for command in "$commands_to_process"; do    
    case $command in
      "persist-log")
        echo "  Persisting bootstrap log"
        persist_log=true;;
      *) echo "Command \"$command\" is unknown, ignoring.";; 
    esac
  done
else
  echo "  None"
fi

# clear log, if it is not persisted
if [ "$persist_log" = false ]; then
  echo -n > bootstrap.log
fi

# bring the containers up
command_docker_compose="$(generate_docker_compose_command) up --remove-orphans -d"
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
    echo "Error occurred during bootstrap of $deployment, when running deployments/$deployment/bootstrap.sh. Check bootstrap.log for details."
    exit 1
  fi
done

# Confirm initialisation process is complete
printf "\nTyk Demo initialisation process completed"
printf "\n-----------------------------------------\n\n"
