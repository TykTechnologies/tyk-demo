#!/bin/bash

# Send POST request that will be rejected, as it's not authenticated
curl -X POST http://tyk-gateway.localhost:8080/streams-authentication/post \
    -H "Content-Type: text/plain" \
    -d "This will fail" \
