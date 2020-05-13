#!/bin/bash

# prevent log file from growing too big - truncate when it reaches over 10000 lines
if [ $(wc -l < bootstrap.log) -gt 10000 ]
then
  echo "" > bootstrap.log
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

# make bootstrap files executable
chmod +x `ls */*.sh` 1> /dev/null 

# make the context data directory
mkdir -p .context-data 1> /dev/null

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