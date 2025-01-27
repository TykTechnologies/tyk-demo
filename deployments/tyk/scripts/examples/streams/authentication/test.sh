#!/bin/bash

# Variables
POST_URL="http://tyk-gateway.localhost:8080/streams-authentication/post"
GET_URL="http://tyk-gateway.localhost:8080/streams-authentication/get/stream"
DATA="test-message-$(date +%s)"
TIMEOUT=10
RESPONSE_FILE=$(mktemp)
AUTH_HEADER="Authorization: streams_authentication"

# Function to clean up background listener
cleanup() {
    if [[ -n "$listener_pid" ]]; then
        kill "$listener_pid" 2>/dev/null || true
        disown "$listener_pid" 2>/dev/null || true # Suppress shell termination messages
    fi
    rm -f "$RESPONSE_FILE"
}
trap cleanup EXIT

# Test unauthenticated request
echo "Testing unauthenticated request..."
if curl -s -o /dev/null -w "%{http_code}" -X POST "$POST_URL" -H "Content-Type: text/plain" -d "$DATA" | grep -q "401"; then
    echo "Unauthenticated request correctly rejected."
else
    echo "Unauthenticated request was not rejected."
    exit 1
fi

# Start listening for the message in the background
curl -N "$GET_URL" -H "$AUTH_HEADER" > "$RESPONSE_FILE" 2>&1 & listener_pid=$!

# Send the authenticated message
echo "Testing authenticated request..."
if ! curl -s -X POST "$POST_URL" -H "Content-Type: text/plain" -H "$AUTH_HEADER" -d "$DATA" >/dev/null; then
    echo "Failed to send authenticated message."
    exit 1
fi

# Poll the response file for the expected message
end_time=$((SECONDS + TIMEOUT))
while [[ $SECONDS -lt $end_time ]]; do
    if grep -q "$DATA" "$RESPONSE_FILE"; then
        echo "Authenticated message received: $DATA"
        exit 0
    fi
    sleep 1
done

echo "Authenticated message not received within timeout period."
exit 1