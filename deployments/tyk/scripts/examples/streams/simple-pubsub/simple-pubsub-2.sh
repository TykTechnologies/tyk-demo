#!/bin/bash

source scripts/common.sh

check_for_wscat

echo "Streams - Simple PubSub"
echo "Part 2: Using websockets"
echo "This script connects to a websocket endpoint, and waits to receive messages."
echo "Messages are sent by script 3."

wscat -c ws://tyk-gateway.localhost:8080/streams-simple-pubsub/ws
