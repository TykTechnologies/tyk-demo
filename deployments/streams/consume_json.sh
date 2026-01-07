#!/bin/bash

# Script to consume JSON messages from the SSE stream endpoint
# Uses the json-consumers consumer group

echo "Starting JSON Consumer Endpoint (Consumer Group: json-consumers)"
echo "Listening on: http://tyk-gateway.localhost:8080/streams-master-data-json/stream"
echo "Press CTRL+C to quit"
echo ""

curl -N http://tyk-gateway.localhost:8080/streams-master-data-json/stream


