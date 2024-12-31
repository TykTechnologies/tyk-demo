cat <<EOF
$(printf "\033[1mStreams - Authenticated PubSub\033[0m")

Part 1: Authenticate as a subscriber

This script connects to a server-sent event endpoint, and waits to receive messages. It authenticates using the Authorization header.

Now use script 2 to send messages, then check back here to see them being received.

Waiting for messages... (press Ctrl+C to stop)

EOF

curl http://tyk-gateway.localhost:8080/streams-authenticated-pubsub/sse \
    -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwicG9sIjoiNjZmZmI5OTMyYTRhNTEwMDAxODZkMzc0IiwiaWF0IjoxNTE2MjM5MDIyfQ.G_rM5NWQIQopOZABTLkZEfnp2XSAiN5vFyRZAOWbtFs'
