echo "Streams - Simple PubSub"
echo "Part 1: Using server-sent events"
echo "This script connects to a server-sent event endpoint, and waits to receive messages."
echo "Messages are sent by script 3."

curl http://tyk-gateway.localhost:8080/streams-simple-pubsub/sse
