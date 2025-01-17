#!/bin/bash

echo "Listening to SSE stream..."

# Start SSE streaming
curl -N http://tyk-gateway.localhost:8080/stream-sse/get/stream
