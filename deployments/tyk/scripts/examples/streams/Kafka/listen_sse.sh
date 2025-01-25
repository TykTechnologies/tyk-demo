#!/bin/bash

echo "Consuming Kafka topic through SSE stream... (CTRL+C to quit)"

# Start SSE streaming
curl -N http://tyk-gateway.localhost:8080/streams-kafka/get/stream
