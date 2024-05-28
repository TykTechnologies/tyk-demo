#!/bin/bash

source scripts/common.sh

service_names=""

for container_id in $(docker ps -q --filter name=tyk-gateway); do
    service_name=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' $container_id)
    service_names="$service_names $service_name"
done

if [ -n "$service_names" ]; then
    eval $(generate_docker_compose_command) up -d --no-deps --force-recreate $service_names
fi
