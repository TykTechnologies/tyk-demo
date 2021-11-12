#!/bin/bash

source scripts/common.sh

echo "Bringing Tyk Demo deployment DOWN"

# deleted bundle assets to prevent them being reused on next startup:
# 1. remove all zip files from bundle server 
rm deployments/tyk/volumes/http-server/*.zip 2> /dev/null
# 2. clear bundle cache from gateway
rm -rf deployments/tyk/volumes/tyk-gateway/middleware/bundles 2> /dev/null

# check if docker compose version is v1.x
check_docker_compose_version

# execute docker compose command
command_docker_compose="$(generate_docker_compose_command) down -v --remove-orphans"
echo "Running docker compose command: $command_docker_compose"
eval $command_docker_compose

if [ "$?" == 0 ]
then
  echo "All containers were stopped and removed"
else
  echo "Error occurred during the following the down command."
fi 
