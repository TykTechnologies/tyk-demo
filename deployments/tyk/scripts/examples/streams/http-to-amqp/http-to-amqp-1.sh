#!/bin/bash

source scripts/common.sh

check_for_wscat

echo "Streams - HTTP to AMQP"
echo "Part 1: Listen for messages"
echo "Once connected, run part two of this example in a different terminal. The messages sent will appear here."
echo "Tyk enables the websocket to consume messages from the AMQP queue."
echo "Connecting to the websocket..."
wscat -c ws://tyk-gateway.localhost:8080/streams-http-to-amqp/ws