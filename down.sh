#!/bin/bash

echo "Bringing Tyk Demo deployment DOWN"

# deleted bundle assets to prevent them being reused on next startup:
# 1. remove all zip files from bundle server 
rm deployments/tyk/volumes/http-server/*.zip 2> /dev/null
# 2. clear bundle cache from gateway
rm -rf deployments/tyk/volumes/tyk-gateway/middleware/bundles 2> /dev/null

# check if docker compose version is v1.x
rm .bootstrap/is_docker_compose_v1 2> /dev/null
regex_docker_compose_version_1='^docker-compose version 1\.'
if [[ $(docker-compose --version) =~ $regex_docker_compose_version_1 ]]; then
  echo "Detected Docker Compose v1"
  touch .bootstrap/is_docker_compose_v1
fi

# build docker compose command
command_docker_compose=""
if [ -f .bootstrap/is_docker_compose_v1 ]; then
  command_docker_compose="docker-compose"
else
  command_docker_compose="docker compose"
fi
while read deployment; do
  command_docker_compose="$command_docker_compose -f deployments/$deployment/docker-compose.yml"
done <.bootstrap/bootstrapped_deployments
command_docker_compose="$command_docker_compose -p tyk-demo --project-directory `pwd` down -v --remove-orphans"

# execute docker compose command
echo "Running docker compose command: $command_docker_compose"
eval $command_docker_compose

if [ "$?" == 0 ]
then
  echo "All containers were stopped and removed"
else
  echo "Error occurred during the following the down command."
fi 
