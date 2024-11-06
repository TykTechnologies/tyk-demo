echo "Streams - HTTP to AMQP"
echo "Part 1: Listen for messages"
echo "Once connected, run part two of this example in a different terminal. The messages sent will appear here."
echo "Tyk enables server-sent events to consume messages from an AMQP queue."
echo "Connecting to the SSE endpoint..."
curl -N http://tyk-gateway.localhost:8080/streams-http-to-amqp/sse