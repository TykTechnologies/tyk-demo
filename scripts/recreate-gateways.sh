#!/bin/bash

source scripts/common.sh

for container_id in $(docker ps -q --filter name=tyk-gateway); do
    service_name=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' $container_id)
    eval $(generate_docker_compose_command) up -d --no-deps --force-recreate $service_name
done
