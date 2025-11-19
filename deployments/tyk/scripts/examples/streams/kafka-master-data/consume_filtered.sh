#!/bin/bash

# Script to simulate a filtered consumer endpoint
# This listens for HTTP POST requests from Tyk Streams (Kafka consumer)
# representing a downstream system that only receives a filtered subset of data

# Check if filter argument is provided (optional)
FILTER_CATEGORY=${1:-""}

echo "Starting Filtered Consumer Endpoint (Consumer Group: filtered-consumers based on category property)"

echo "Listening on: http://tyk-gateway.localhost:8080/streams-master-data-filtered/stream"
echo ""
echo "Press CTRL+C to quit"
echo ""

# This endpoint receives POST requests from Tyk Streams with filtered messages
# In a real scenario, this would be your ERP system's HTTP endpoint
# The filtering logic is configured in Tyk Streams based on master data properties
curl -N http://tyk-gateway.localhost:8080/streams-master-data-filtered/stream

