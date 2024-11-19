#!/bin/bash

# displays the reported rate limiter configuration for each tyk gateway
for container in $(docker ps --filter name=tyk-gateway --format '{{.Names}}'); do
    rl_config=$(docker logs $container 2>&1 | grep --line-buffered 'RATELIMIT' | awk -F'"' '{print $4}')
    echo "Container $container: $rl_config"
done
