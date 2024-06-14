#!/bin/bash

source scripts/common.sh

eval $(generate_docker_compose_command) stop tyk-mdcb