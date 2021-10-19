#!/bin/bash

source scripts/common.sh

# restart bootstrap log file
echo -n > bootstrap.log

# check .env file exists
if [ ! -f .env ]
then
  echo "ERROR: Docker environment file missing. Review 'getting started' steps in README.md."
  exit 1
fi

# check hostnames exist
for i in "${tyk_demo_hostnames[@]}"
do
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

# ensure Docker environment variables are correctly set before creating containers
# these allow for tracing and instrumentation deployments to be easily used, without having to manually set the environment variables
if [[ "$*" == *tracing* ]]
then
  set_docker_environment_value "TRACING_ENABLED" "true"
else
  set_docker_environment_value "TRACING_ENABLED" "false"
fi

if [[ "$*" == *instrumentation* ]]
then
  set_docker_environment_value "INSTRUMENTATION_ENABLED" "1"
else
  set_docker_environment_value "INSTRUMENTATION_ENABLED" "0"
fi

# create and run the docker compose command
command_docker_compose="docker-compose -f deployments/tyk/docker-compose.yml"
for var in "$@"
do
  #   the `tyk` deployment is already included, so don't duplicate it
  if [ "$var" != "tyk" ]
  then
    command_docker_compose="$command_docker_compose -f deployments/$var/docker-compose.yml"
  fi
done

echo "$command_docker_compose -p tyk-demo --project-directory $(pwd)" > .bootstrap/docker-compose-prefix-command
echo "my .bootstrap/docker-compose-prefix-command: "
cat .bootstrap/docker-compose-prefix-command
echo -n "----"
command_docker_compose="$command_docker_compose -p tyk-demo --project-directory $(pwd) up --remove-orphans -d"
echo "Starting containers: $command_docker_compose"
eval $command_docker_compose
if [ "$?" != 0 ]
then
  echo "Error occurred when using docker-compose to bring containers up"
  exit 1
fi

# alway run the tyk bootstrap first
deployments/tyk/bootstrap.sh 2>> bootstrap.log
if [ "$?" != 0 ]
then
  echo "Error occurred during bootstrap of 'tyk' deployment. Check bootstrap.log for details."
  exit 1
fi

# run bootstrap scripts for any feature deployments specified
for var in "$@"
do
  # the `tyk` deployment is already included, so don't duplicate it
  if [ "$var" != "tyk" ]
  then
    echo "$var" >> ./.bootstrap/bootstrapped_deployments
    eval "deployments/$var/bootstrap.sh"
    if [ "$?" != 0 ]
    then
      echo "Error occurred during bootstrap of $var, when running deployments/$var/bootstrap.sh. Check bootstrap.log for details."
      exit 1
    fi
  fi
done

# Confirm bootstrap is compelete
printf "\nTyk-Demo bootstrap completed\n"
printf "\n----------------------------\n\n"
