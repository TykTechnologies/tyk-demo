#!/bin/bash

command_docker_compose="docker-compose -f deployments/tyk/docker-compose.yml"
for var in "$@"
do
  #   the `tyk` deployment is already included, so don't duplicate it
  if [ "$var" != "tyk" ]
  then
    command_docker_compose="$command_docker_compose -f deployments/$var/docker-compose.yml"
  fi
done
command_docker_compose="$command_docker_compose -p tyk-pro-docker-demo-extended --project-directory $(pwd) down -v"
eval $command_docker_compose