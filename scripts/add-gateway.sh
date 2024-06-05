#!/bin/bash

# Creates a new Tyk Gateway container, using the same configuration as the base Tyk deployment Gateway
# You can specify the name of the container using an argument, otherwise a random name is assigned

if [ "$1" == "" ]; then
  docker run \
    -d \
    -P \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/tyk.conf:/opt/tyk-gateway/tyk.conf \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/certs:/opt/tyk-gateway/certs \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/middleware:/opt/tyk-gateway/middleware \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/plugins:/opt/tyk-gateway/plugins \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/templates/error_401.json:/opt/tyk-gateway/templates/error_401.json \
    -v $(pwd)/deployments/tyk/volumes/databases/GeoLite2-Country.mmdb:/opt/tyk-gateway/databases/GeoLite2-Country.mmdb \
    --network tyk-demo_tyk \
    tykio/tyk-gateway:v5.3.0
else
  docker run \
    --name $1 \
    -d \
    -P \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/tyk.conf:/opt/tyk-gateway/tyk.conf \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/certs:/opt/tyk-gateway/certs \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/middleware:/opt/tyk-gateway/middleware \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/plugins:/opt/tyk-gateway/plugins \
    -v $(pwd)/deployments/tyk/volumes/tyk-gateway/templates/error_401.json:/opt/tyk-gateway/templates/error_401.json \
    -v $(pwd)/deployments/tyk/volumes/databases/GeoLite2-Country.mmdb:/opt/tyk-gateway/databases/GeoLite2-Country.mmdb \
    --network tyk-demo_tyk \
    tykio/tyk-gateway:v5.3.0
fi
