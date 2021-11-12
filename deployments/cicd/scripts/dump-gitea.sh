#!/bin/bash

source scripts/common.sh

# generates a Gitea archive dump of the configuration and repositories
# then copies the file from the container and overwrites the tracked archive in this repo

check_docker_compose_version

command_docker_compose="$(generate_docker_compose_command) exec -T -u git gitea sh -c \"cd /data/gitea; rm gitea-dump.zip; gitea dump -c /data/gitea/conf/app.ini --f gitea-dump.zip\""
eval $command_docker_compose

command_docker_compose="$(generate_docker_compose_command) ps -q gitea"
gitea_container_id=$(eval $command_docker_compose)

docker cp $gitea_container_id:/data/gitea/gitea-dump.zip deployments/cicd/volumes/gitea/gitea-dump.zip