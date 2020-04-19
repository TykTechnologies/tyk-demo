#!/bin/bash

docker run \
  -d \
  -p 8088:8080 \
  -v $(pwd)/volumes/tyk-gateway/tyk.conf:/opt/tyk-gateway/tyk.conf \
  -v $(pwd)/volumes/tyk-gateway/middleware:/opt/tyk-gateway/middleware \
  --network tyk-pro-docker-demo-extended_tyk \
  tykio/tyk-gateway:latest