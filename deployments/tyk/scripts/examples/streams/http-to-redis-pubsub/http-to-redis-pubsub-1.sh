cat <<EOF
$(printf "\033[1mStreams - HTTP to Redis Pub/Sub\033[0m")

Part 1: Listening to a Redis Channel

Once connected, run part two of this example in a different terminal. The messages sent will appear here.

Connecting to the Redis channel...

EOF

docker exec tyk-demo-tyk-redis-1 redis-cli SUBSCRIBE streams
