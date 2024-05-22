#!/bin/bash

source scripts/common.sh

eval $(generate_docker_compose_command) up -d --no-deps --force-recreate tyk-gateway tyk-gateway-2 tyk-gateway-3 tyk-gateway-4
