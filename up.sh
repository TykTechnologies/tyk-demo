#!/bin/bash

source scripts/common.sh

# prevent log file from growing too big - truncate when it reaches over 10000 lines
if [ $(wc -l < bootstrap.log) -gt 10000 ]
then
  echo "" > bootstrap.log
fi

# make scripts executable
chmod +x `ls */*.sh` 1> /dev/null 

# make the context data directory
mkdir -p .context-data 1> /dev/null

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
command_docker_compose="$command_docker_compose -p tyk-pro-docker-demo-extended --project-directory $(pwd) up -d"
eval $command_docker_compose

# alway run the tyk bootstrap first
deployments/tyk/bootstrap.sh

# run bootstrap scripts for any feature deployments specified
for var in "$@"
do
  # the `tyk` deployment is already included, so don't duplicate it
  if [ "$var" != "tyk" ]
  then
    eval "deployments/$var/bootstrap.sh"
  fi
done

# if an error was logged, report it
if [ -f .bootstrap_error_occurred ]
then
  rm .bootstrap_error_occurred
  echo "Error occurred during bootstrap, check bootstrap.log for information"
fi