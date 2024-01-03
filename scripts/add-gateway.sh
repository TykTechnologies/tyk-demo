#!/bin/bash

# Creates a new Tyk Gateway container, using the same configuration as the base Tyk deployment Gateway

docker run \
  -d \
  -P \
  -v $(pwd)/deployments/tyk/volumes/tyk-gateway/tyk.conf:/opt/tyk-gateway/tyk.conf \
  -v $(pwd)/deployments/tyk/volumes/tyk-gateway/middleware:/opt/tyk-gateway/middleware \
  --network tyk-demo_tyk \
  tykio/tyk-gateway:v5.2.5
