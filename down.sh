#!/bin/bash

command_docker_compose="docker-compose -f deployments/tyk/docker-compose.yml"
bootstrapped_deployments_file="./.bootstrap/bootstrapped_deployments"
if test -f "$bootstrapped_deployments_file"; then
while IFS= read -r deployment
do
  #   the `tyk` deployment is already included, so don't duplicate it
  if [ "$deployment" != "" ] && [ "$deployment" != "tyk" ]
  then
    echo "Removing '$deployment' deployment"
    command_docker_compose="$command_docker_compose -f deployments/$deployment/docker-compose.yml"
  fi
done < $bootstrapped_deployments_file
fi
command_docker_compose="$command_docker_compose -p tyk-demo --project-directory $(pwd) down -v"
echo "Running docker-compose down: " $command_docker_compose
eval $command_docker_compose
if [ "$?" == 0 ]
then
  echo "All containers were stopped and removed"
else
 echo "Error occurred during the following the down command."
fi 
