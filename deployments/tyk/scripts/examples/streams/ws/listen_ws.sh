#!/bin/bash

source scripts/common.sh

check_for_websocat

WS_URL=ws://tyk-gateway.localhost:8080/streams-ws/get/ws

# Connect to the WebSocket stream
echo "Listening for WebSocket messages at $WS_URL"
websocat $WS_URL
