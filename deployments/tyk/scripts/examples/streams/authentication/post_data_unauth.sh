#!/bin/bash

# Send POST request that will be rejected, due as not authenticated
curl -X POST http://tyk-gateway.localhost:8080/streams-authentication/post \
    -H "Content-Type: text/plain" \
    -d "This will fail" \