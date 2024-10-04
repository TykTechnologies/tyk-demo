echo "Streams - Validated PubSub"
echo "Part 1: Listening for validated server-sent events"
echo "This script connects to a server-sent event endpoint, and waits to receive messages."
echo "Use script 3 to send messages."

curl http://tyk-gateway.localhost:8080/streams-simple-pubsub/validated-sse
