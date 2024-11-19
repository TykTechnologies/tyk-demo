#!/bin/bash

# This example shows how Tyk can perform simple TCP proxying. In this case, it is proxying to Redis.
# The example runs a redis-cli PING command, specifying the Tyk gateway (tyk-gateway) as the host, and the port that the API definition is configured to listen on (9004).
# The response is 'PONG', which shows that the command was successfully proxied via the gateway.

echo "Running a Redis CLI 'PING' command via the Tyk gateway"
docker exec tyk-demo-tyk-redis-1 redis-cli -h tyk-gateway -p 9004 PING
