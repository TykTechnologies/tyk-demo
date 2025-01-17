#!/bin/bash

# Check if data argument is provided
if [ -z "$1" ]; then
  echo "Usage: ./post_data.sh <data>"
  exit 1
fi

DATA=$1

echo "Posting data: $DATA"

# Send POST request with the provided data
curl -X POST http://tyk-gateway.localhost:8080/stream-sse/post -H "Content-Type: text/plain" -d "$DATA"
