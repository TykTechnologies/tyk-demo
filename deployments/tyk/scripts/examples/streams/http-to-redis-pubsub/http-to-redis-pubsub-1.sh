#!/bin/bash

echo "Streams - HTTP to Redis Pub/Sub"
echo "Part 1: Listening to a Redis Channel"
echo "Once connected, run part two of this example in a different terminal. The messages sent will appear here."
echo "Connecting to the Redis channel..."
docker exec tyk-demo-tyk-redis-1 redis-cli SUBSCRIBE streams
