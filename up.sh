#!/bin/bash

# delete the bootstrap log file, so it can be restarted
rm bootstrap.log

# create and run the docker compose command
command_docker_compose="docker-compose -f tyk/docker-compose.yml"
for var in "$@"
do
  command_docker_compose="$command_docker_compose -f $var/docker-compose.yml"
done
command_docker_compose="$command_docker_compose -p tyk-pro-docker-demo-extended --project-directory $(pwd) up -d"
eval $command_docker_compose

# make bootstrap files executable
chmod +x `ls */*.sh` 1> /dev/null 

# make the context data directory
mkdir -p .context-data 1> /dev/null

# alway run the tyk bootstrap first
tyk/bootstrap.sh

# run bootstrap scripts for any feature deployments specified
for var in "$@"
do
  eval "$var/bootstrap.sh"
done