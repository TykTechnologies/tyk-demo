#!/bin/bash

source scripts/common.sh

# check if docker compose version is v1.x
check_docker_compose_version

docker_compose_command="$(generate_docker_compose_command) $1"

echo "Running command: $docker_compose_command"

eval $docker_compose_command