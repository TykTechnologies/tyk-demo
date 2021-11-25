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

# make the context data directory and clear and data from an existing directory
mkdir -p .context-data 1> /dev/null
rm -f .context-data/*

# clear the .bootstrap/bootstrapped_deployments from deployments
mkdir -p .bootstrap 1> /dev/null
echo -n > .bootstrap/bootstrapped_deployments

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

# create a file which contains names of all the deployments
# this determines the order in which the deployments are bootstrapped
# the default "tyk" deployment is added first
echo "tyk" >> .bootstrap/bootstrapped_deployments
# add any deployments which were specified as arguments
for deployment in "$@"; do
  # avoid re-adding "tyk"
  if [ "$deployment" != "tyk" ]; then
    echo "$deployment" >> .bootstrap/bootstrapped_deployments
  fi
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
while read deployment; do
  eval "deployments/$deployment/bootstrap.sh"
  if [ "$?" != 0 ]; then
    echo "Error occurred during bootstrap of $deployment, when running deployments/$deployment/bootstrap.sh. Check bootstrap.log for details."
    exit 1
  fi
done < .bootstrap/bootstrapped_deployments

# Confirm bootstrap is compelete
printf "\nTyk Demo bootstrap completed\n"
printf "\n----------------------------\n\n"
