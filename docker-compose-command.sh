#!/bin/bash

source scripts/common.sh

docker_compose_command="$(generate_docker_compose_command) $@"

echo "Running command: $docker_compose_command"

eval $docker_compose_command