#!/bin/bash

docker-compose \
    -f deployments/tyk/docker-compose.yml \
    -f deployments/cicd/docker-compose.yml \
    -p tyk-pro-docker-demo-extended \
    --project-directory $(pwd) \
    exec -u git gitea sh -c "cd /data/gitea; rm gitea-dump.zip; gitea dump -c /data/gitea/conf/app.ini --f gitea-dump.zip"

gitea_container_id=$(docker-compose \
    -f deployments/tyk/docker-compose.yml \
    -f deployments/cicd/docker-compose.yml \
    -p tyk-pro-docker-demo-extended \
    --project-directory $(pwd) \
    ps -q gitea)

docker cp $gitea_container_id:/data/gitea/gitea-dump.zip deployments/cicd/volumes/gitea/gitea-dump.zip