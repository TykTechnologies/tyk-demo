#!/bin/bash

# Script to consume XML messages from the SSE stream endpoint
# Uses the xml-consumers consumer group
# Messages are transformed from JSON to XML before streaming

echo "Starting XML Consumer Endpoint (Consumer Group: xml-consumers)"
echo "Listening on: http://tyk-gateway.localhost:8080/streams-master-data-xml/stream"
echo "Press CTRL+C to quit"
echo ""

curl -N http://tyk-gateway.localhost:8080/streams-master-data-xml/stream


