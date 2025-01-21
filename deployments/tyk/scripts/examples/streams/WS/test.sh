#!/bin/bash

# Variables
POST_URL="http://tyk-gateway.localhost:8080/streams-ws/post"
WS_URL="ws://tyk-gateway.localhost:8080/streams-ws/get/ws"
DATA="test-message-$(date +%s)"
TIMEOUT=10
RESPONSE_FILE=$(mktemp)

# Check if websocat is installed
if ! command -v websocat >/dev/null 2>&1; then
    echo "Error: websocat is not installed. Please install websocat and try again."
    exit 1
fi

# Function to clean up background listener
cleanup() {
    if [[ -n "$listener_pid" ]]; then
        kill "$listener_pid" 2>/dev/null
        wait "$listener_pid" 2>/dev/null || true  # Wait for process to fully exit
    fi
    rm -f "$RESPONSE_FILE"
}
trap cleanup EXIT

# Function to start websocat and return the PID
start_websocat() {
    websocat -Un "$WS_URL" > "$RESPONSE_FILE" &
    listener_pid=$!  # Capture the PID
}

# Start websocat in the background and get the PID
start_websocat

# Allow some time for the WebSocket connection to establish
sleep 2
# Send the message using curl
if ! curl -s -X POST "$POST_URL" -H "Content-Type: text/plain" -d "$DATA" >/dev/null; then
    echo "Error: Failed to send message."
    exit 1
fi

# Poll the response file for the expected message
end_time=$((SECONDS + TIMEOUT))
while [[ $SECONDS -lt $end_time ]]; do
    if grep -q "$DATA" "$RESPONSE_FILE"; then
        echo "Message received: $DATA"
        exit 0
    fi
    sleep 1
done

echo "Error: Message not received within timeout period."
exit 1
