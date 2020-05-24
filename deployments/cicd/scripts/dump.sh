docker-compose \
    -f deployments/tyk/docker-compose.yml \
    -f deployments/cicd/docker-compose.yml \
    -p tyk-pro-docker-demo-extended \
    --project-directory $(pwd) \
    exec -u git gitea sh -c "cd /data/dump; gitea dump -c /data/gitea/conf/app.ini"


# use this command for zip?
# zip -r file.zip . -x "gitea/indexers/*" "gitea/queues/*"