#!/bin/bash

source scripts/common.sh

check_docker_compose_version

eval $(generate_docker_compose_command) stop tyk-mdcb