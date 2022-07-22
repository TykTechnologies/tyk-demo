#!/bin/bash

source scripts/common.sh

echo "Bringing Tyk Demo deployment UP"

# restart bootstrap log file
echo -n > bootstrap.log

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

# list of deployments to bootstrap
deployments_to_create=()

if [[ -s .bootstrap/bootstrapped_deployments ]]; then
  echo "Existing deployments found. Only newly specified deployments will be created."
else
  echo "No existing deployments found. All specified deployments will be created."
  # create a file which contains names of all the deployments
  # this determines the order in which the deployments are bootstrapped
  # the default "tyk" deployment is added automatically as the first deployment
  echo "tyk" >> .bootstrap/bootstrapped_deployments
  deployments_to_create+=("tyk")
fi

# extract new deployments from arguments
for deployment in "$@"; do
  # skip "tyk" deployment, as it is handled automatically
  [ "$deployment" == "tyk" ] && continue

  # skip existing deployments, to avoid rebootstrapping
  if [ ! -z $(grep "$deployment" ".bootstrap/bootstrapped_deployments") ]; then 
    echo "Deployment \"$deployment\" already exists, skipping."
    continue
  fi

  echo "$deployment" >> .bootstrap/bootstrapped_deployments
  deployments_to_create+=("$deployment")
done

# check if bootstrap is needed
if [ ${#deployments_to_create[@]} -eq 0 ]; then
  echo "Specified deployments already exist. Exiting."
  echo "Tip: If you want to recreate the existing deployment, run the down.sh script first."
  exit
fi

# display deployments to bootstrap
echo "Deployments to create:"
for deployment in "${deployments_to_create[@]}"; do
  echo "  $deployment"
done

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

# Confirm bootstrap is complete
printf "\nTyk Demo bootstrap completed\n"
printf "\n----------------------------\n\n"
