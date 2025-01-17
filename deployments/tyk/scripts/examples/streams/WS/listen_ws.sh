#!/bin/bash

# Ensure wscat is installed
if ! command -v wscat &> /dev/null; then
    echo "Error: wscat is not installed. Install it using 'npm install -g wscat'."
    exit 1
fi

# Connect to the WebSocket stream
echo "Listening for WebSocket messages at ws://tyk-gateway.localhost:8080/stream-ws/get/ws"
wscat -c ws://tyk-gateway.localhost:8080/stream-ws/get/ws
