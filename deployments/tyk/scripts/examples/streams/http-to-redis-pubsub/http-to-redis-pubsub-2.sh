#!/bin/bash

echo "Streams - HTTP to Redis Pub/Sub"
echo "Part 2: Sending a message"
echo "Each time this script is run, the message \"Hello, Tyk Streams!\" will be received through the Redis channel in part 1. Check the other terminal to see the messages."
curl -d 'Hello, Tyk Streams!' http://tyk-gateway.localhost:8080/streams-http-to-redis-pubsub/post
