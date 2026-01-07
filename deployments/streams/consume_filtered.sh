#!/bin/bash

# Script to consume filtered messages from the SSE stream endpoint
# Uses the filtered-consumers consumer group
# Only receives messages matching the filter criteria (Electronics category)

echo "Starting Filtered Consumer Endpoint (Consumer Group: filtered-consumers based on category property)"
echo "Listening on: http://tyk-gateway.localhost:8080/streams-master-data-filtered/stream"
echo "Press CTRL+C to quit"
echo ""

curl -N http://tyk-gateway.localhost:8080/streams-master-data-filtered/stream

