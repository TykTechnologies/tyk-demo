#!/bin/bash

# Script to simulate a JSON consumer endpoint
# This listens for HTTP POST requests from Tyk Streams (Kafka consumer)
# representing a downstream system that accepts canonical JSON format

echo "Starting JSON Consumer Endpoint (Consumer Group: json-consumers)"
echo "This simulates an ERP system that accepts canonical JSON format"
echo "Listening on: http://tyk-gateway.localhost:8080/streams-master-data-json/stream"
echo ""
echo "Press CTRL+C to quit"
echo ""

# This endpoint receives POST requests from Tyk Streams when messages arrive on Kafka
# In a real scenario, this would be your ERP system's HTTP endpoint
curl -N http://tyk-gateway.localhost:8080/streams-master-data-json/stream

