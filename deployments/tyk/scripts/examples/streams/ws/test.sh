#!/bin/bash

# Variables
POST_URL="http://tyk-gateway.localhost:8080/streams-ws/post"
WS_URL="ws://tyk-gateway.localhost:8080/streams-ws/get/ws"
DATA="test-message-$(date +%s)"
TIMEOUT=10
RESPONSE_FILE=$(mktemp)

# Cleanup function
cleanup() {
    [[ -n "$listener_pid" ]] && kill "$listener_pid" 2>/dev/null && disown "$listener_pid" 2>/dev/null || true
    rm -f "$RESPONSE_FILE"
}
trap cleanup EXIT

# Start WebSocket listener in the background
websocat -Un "$WS_URL" > "$RESPONSE_FILE" 2>&1 & listener_pid=$!
sleep 2

# Send the message
if ! curl -s -X POST -H "Content-Type: text/plain" -d "$DATA" "$POST_URL" >/dev/null; then
    echo "Failed to send message."
    exit 1
fi

# Poll for expected message
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
