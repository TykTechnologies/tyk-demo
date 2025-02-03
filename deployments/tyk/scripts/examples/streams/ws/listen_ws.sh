#!/bin/bash

# Ensure wscat is installed
if ! command -v wscat &> /dev/null; then
    echo "Error: wscat is not installed. Install it using 'npm install -g wscat'."
    exit 1
fi

WS_URL=ws://tyk-gateway.localhost:8080/streams-ws/get/ws

# Connect to the WebSocket stream
echo "Listening for WebSocket messages at $WS_URL"
wscat -c $WS_URL
