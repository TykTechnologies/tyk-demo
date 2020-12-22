#!/bin/bash

# deleted bundle assets to prevent them being reused on next startup:
# 1. remove all zip files from bundle server 
rm deployments/tyk/volumes/http-server/*.zip
# 2. clear bundle cache from gateway
rm -rf deployments/tyk/volumes/tyk-gateway/middleware/bundles

# bring down docker compose deployment 
./docker-compose-command.sh down -v --remove-orphans
if [ "$?" == 0 ]
then
  echo "All containers were stopped and removed"
else
  echo "Error occurred during the following the down command."
fi 
