#!/bin/bash

echo "Listening to SSE stream... (CTRL+C to quit)"

# Start SSE streaming
curl -N http://tyk-gateway.localhost:8080/streams-authentication/get/stream \
    -H "Authorization: streams_authentication"