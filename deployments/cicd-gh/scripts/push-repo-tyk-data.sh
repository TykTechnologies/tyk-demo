#!/bin/bash

# adds, commits and pushes any data in the tyk-data repo

gitea_tyk_data_repo_path=$(cat .context-data/gitea-tyk-data-repo-path)
gitea_username=$(cat .context-data/gitea-username)
gitea_password=$(cat .context-data/gitea-password)

git -C $gitea_tyk_data_repo_path add .
git -C $gitea_tyk_data_repo_path commit -m "Latest changes"
git -C $gitea_tyk_data_repo_path push "http://$gitea_username:$gitea_password@localhost:13000/gitea-user/tyk-data.git/"