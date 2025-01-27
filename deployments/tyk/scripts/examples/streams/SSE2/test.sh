#!/bin/bash

# Variables
POST_URL="http://tyk-gateway.localhost:8080/streams-sse/post"
GET_URL="http://tyk-gateway.localhost:8080/streams-sse/get/stream"
DATA="test-message-$(date +%s)"
TIMEOUT=10
RESPONSE_FILE=$(mktemp)

# Function to clean up background listener
cleanup() {
    if [[ -n "$listener_pid" ]]; then
        kill "$listener_pid" 2>/dev/null || true
        disown "$listener_pid" 2>/dev/null || true # Suppress shell termination messages
    fi
    rm -f "$RESPONSE_FILE"
}
trap cleanup EXIT

# Start listening for the message in the background
curl -N "$GET_URL" > "$RESPONSE_FILE" 2>&1 & listener_pid=$!

# Send the message
if ! curl -s -X POST "$POST_URL" -H "Content-Type: text/plain" -d "$DATA" >/dev/null; then
    echo "Failed to send message."
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

echo "Message not received within timeout period."
exit 1
