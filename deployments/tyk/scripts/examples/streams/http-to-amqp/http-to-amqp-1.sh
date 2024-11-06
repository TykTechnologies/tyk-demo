echo "Streams - HTTP to AMQP"
echo "Part 1: Listen for messages"
echo "Once connected, run part two of this example in a different terminal. The messages sent by part 2 will appear here."
echo "Tyk enables messages in am AMQP queue to be consumed using server-sent events."
echo "Connecting to the SSE endpoint..."
curl -N http://tyk-gateway.localhost:8080/streams-http-to-amqp/sse