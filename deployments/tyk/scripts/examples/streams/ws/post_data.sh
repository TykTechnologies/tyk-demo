#!/bin/bash

# Check if a message is provided
if [ -z "$1" ]; then
    echo "Usage: $0 \"Your message here\""
    exit 1
fi

MESSAGE=$1

echo "Posting message $MESSAGE"

curl http://tyk-gateway.localhost:8080/streams-ws/post -H "Content-Type: text/plain" -d "$MESSAGE"
