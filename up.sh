#!/bin/bash

source scripts/common.sh

# check .env file exists
if [ ! -f .env ]
then
  echo "ERROR: Docker environment file missing. Review 'getting started' steps in README.md."
  exit 1
fi

# check dashboard licence defined
if ! grep -q "DASHBOARD_LICENCE=" .env
then
  echo "ERROR: Dashboard licence missing from Docker environment file. Review 'getting started' steps in README.md."
  exit 1
fi

# check that jq is available
command -v jq >/dev/null 2>&1 || { echo >&2 "ERROR: JQ is required, but it's not installed. Review 'getting started' steps in README.md."; exit 1; }

# prevent log file from growing too big - truncate when it reaches over 10000 lines
if [ -f bootstrap.log ] && [  $(wc -l < bootstrap.log) -gt 10000 ]
then
  echo "" > bootstrap.log
fi

# make the context data directory and clear and data from an existing directory
mkdir -p .context-data 1> /dev/null
rm -f .context-data/*

# make sure error flag is not present
rm -f .bootstrap_error_occurred

# clear the .bootstrap/bootstrapped_deployments from deployments
mkdir -p .bootstrap 1> /dev/null
echo -n > .bootstrap/bootstrapped_deployments

# ensure Docker environment variables are correctly set before creating containers
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

command_docker_compose="$command_docker_compose -p tyk-demo --project-directory $(pwd) up --remove-orphans -d"
eval $command_docker_compose
if [ "$?" != 0 ]
then
  echo "Error occurred when using docker-compose to bring containers up"
  exit
fi
echo "Starting containers: $command_docker_compose"

# alway run the tyk bootstrap first
deployments/tyk/bootstrap.sh 2>> bootstrap.log
if [ "$?" != 0 ]
then
  echo "Error occurred during bootstrap of 'tyk' deployment. Check bootstrap.log for details."
  exit
fi

# run bootstrap scripts for any feature deployments specified
for var in "$@"
do
  # the `tyk` deployment is already included, so don't duplicate it
  if [ "$var" != "tyk" ]
  then
    eval "deployments/$var/bootstrap.sh"
    if [ "$?" != 0 ]
    then
      echo "Error occurred during bootstrap of $var, when running deployments/$var/bootstrap.sh. Check bootstrap.log for details."
      exit
    else
      echo "$var" >> ./.bootstrap/bootstrapped_deployments
    fi
  fi
done

if [ -f .bootstrap_error_occurred ]
then
  # if an error was logged, report it
  printf "\nError occurred during bootstrap, check bootstrap.log for information\n\n"
else
  # Confirm bootstrap is compelete
  printf "\nTyk-Demo bootstrap completed\n"
  printf "\n----------------------------\n\n"
fi
