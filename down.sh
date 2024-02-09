#!/bin/bash

source scripts/common.sh

echo "Bringing Tyk Demo deployment DOWN"

# check if docker compose version is v1.x
check_docker_compose_version

# check if deployments exist
if [[ -s .bootstrap/bootstrapped_deployments ]]; then
  # display deployments to be removed
  echo "Deployments to remove:"
  while read deployment; do
    echo "  $deployment"
  done < .bootstrap/bootstrapped_deployments
else
  echo "No deployments to remove. Exiting."
  exit
fi

# execute docker compose command
command_docker_compose="$(generate_docker_compose_command) down -v --remove-orphans"
echo "Running docker compose command: $command_docker_compose"
eval $command_docker_compose

# run teardown scripts, if they exist
while read deployment; do
  teardownPath="deployments/$deployment/teardown.sh"
  if [ -f $teardownPath ]; then
    echo "Performing teardown for $deployment"
    eval ./deployments/$deployment/teardown.sh
  fi
done < .bootstrap/bootstrapped_deployments

if [ "$?" == 0 ]; then
  echo "All containers were stopped and removed"
  
  # deleted bundle assets to prevent them being reused on next startup:
  # 1. remove all zip files from bundle server 
  rm deployments/tyk/volumes/http-server/*.zip 2> /dev/null
  # 2. clear bundle cache from gateway
  rm -rf deployments/tyk/volumes/tyk-gateway/middleware/bundles 2> /dev/null

  # clear the bootstraped deployments
  echo -n > .bootstrap/bootstrapped_deployments

  # clear context data
  rm -f .context-data/* 1> /dev/null
else
  echo "Error occurred during the following the down command."
fi 
