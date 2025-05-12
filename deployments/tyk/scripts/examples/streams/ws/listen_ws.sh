#!/bin/bash

# Ensure wscat is installed
if ! command -v websocat &> /dev/null; then
    echo "Error: websocat is not installed. Install it using 'brew install websocat' (MacOS)."
    exit 1
fi

WS_URL=ws://tyk-gateway.localhost:8080/streams-ws/get/ws

# Connect to the WebSocket stream
echo "Listening for WebSocket messages at $WS_URL"
websocat $WS_URL
