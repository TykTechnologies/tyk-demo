#!/bin/bash

tyk_data_repo_path=$(cat .context-data/tyk-data-repo-path)

git -C $tyk_data_repo_path add .
git -C $tyk_data_repo_path commit -m "API and Policy data"
git -C $tyk_data_repo_path push