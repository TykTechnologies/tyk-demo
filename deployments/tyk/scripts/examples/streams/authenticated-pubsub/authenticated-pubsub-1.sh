echo "Streams - Authenticated PubSub"
echo "Part 1: Authenticate as a subscriber"
echo "This script connects to a server-sent event endpoint, and waits to receive messages. It authenticates using the Authorization header."
echo "Use script 2 to send messages, then check back here to see them being received."

curl http://tyk-gateway.localhost:8080/streams-authenticated-pubsub/sse \
    -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwicG9sIjoiNjZmZmI5OTMyYTRhNTEwMDAxODZkMzc0IiwiaWF0IjoxNTE2MjM5MDIyfQ.G_rM5NWQIQopOZABTLkZEfnp2XSAiN5vFyRZAOWbtFs'
