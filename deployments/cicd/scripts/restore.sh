docker-compose \
    -f deployments/tyk/docker-compose.yml \
    -f deployments/cicd/docker-compose.yml \
    -p tyk-pro-docker-demo-extended \
    --project-directory $(pwd) \
    exec gitea sh -c "chmod +x /data/restore.sh; ./data/restore.sh"