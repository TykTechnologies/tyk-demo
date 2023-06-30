#!/bin/bash

source scripts/common.sh

# generates a Gitea archive dump of the configuration and repositories
# then copies the file from the container and overwrites the tracked archive in this repo

check_docker_compose_version

eval "$(generate_docker_compose_command) exec -d -u git gitea sh -c \"cd /data/gitea; rm gitea-dump.zip; gitea dump -c /data/gitea/conf/app.ini --f gitea-dump.zip\""

docker cp $(get_service_container_id gitea):/data/gitea/gitea-dump.zip deployments/cicd/volumes/gitea/gitea-dump.zip