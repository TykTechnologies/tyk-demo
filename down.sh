#!/bin/bash

command_docker_compose="docker-compose -f tyk/docker-compose.yml"
for var in "$@"
do
  command_docker_compose="$command_docker_compose -f $var/docker-compose.yml"
done
command_docker_compose="$command_docker_compose -p tyk-pro-docker-demo-extended --project-directory $(pwd) down -v"
eval $command_docker_compose