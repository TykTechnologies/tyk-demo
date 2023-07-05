#!/bin/bash

source scripts/common.sh

# generates a Gitea archive dump of the configuration and repositories
# then copies the file from the container and overwrites the tracked archive in this repo
# note: script must be run from repo root i.e. run as ./deployments/cicd-jenkins/scripts/dump-gitea.sh

check_docker_compose_version

$(generate_docker_compose_command) exec -d -u git gitea sh -c "cd /data/gitea; rm gitea-dump.zip; gitea dump -c /data/gitea/conf/app.ini --f gitea-dump.zip"

# sleep 2 seconds to give time for the command issue by the previous statement to fully complete on the container
sleep 2

docker cp $(get_service_container_id gitea):/data/gitea/gitea-dump.zip deployments/cicd-jenkins/volumes/gitea/gitea-dump.zip
