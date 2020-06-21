#!/bin/bash

docker-compose -f deployments/tyk/docker-compose.yml -f deployments/mdcb/docker-compose.yml -p tyk-demo --project-directory $(pwd) start tyk-mdcb