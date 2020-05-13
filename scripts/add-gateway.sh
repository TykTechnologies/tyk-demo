#!/bin/bash

docker run \
  -d \
  -P \
  -v $(pwd)/deployments/tyk/volumes/tyk-gateway/tyk.conf:/opt/tyk-gateway/tyk.conf \
  -v $(pwd)/deployments/tyk/volumes/tyk-gateway/middleware:/opt/tyk-gateway/middleware \
  --network tyk-pro-docker-demo-extended_tyk \
  tykio/tyk-gateway:latest