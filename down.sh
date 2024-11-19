#!/bin/bash

source scripts/common.sh

echo "Bringing Tyk Demo deployment DOWN"

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

if [ "$?" != 0 ]; then
  echo "Error when running 'docker compose down' command"
  exit 1
fi

# run teardown scripts, if they exist
while read deployment; do
  teardownPath="deployments/$deployment/teardown.sh"
  if [ -f $teardownPath ]; then
    echo "Performing teardown for $deployment deployment"
    eval ./deployments/$deployment/teardown.sh
    if [ "$?" != 0 ]; then
      echo "Error when running teardown for $deployment deployment"
    fi
  fi
done < .bootstrap/bootstrapped_deployments

echo "All containers were stopped and removed"

# clear the bootstraped deployments
echo -n > .bootstrap/bootstrapped_deployments

# clear context data
rm -f .context-data/* 1> /dev/null
