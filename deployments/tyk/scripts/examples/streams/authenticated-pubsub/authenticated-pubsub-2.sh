cat <<EOF
$(printf "\033[1mStreams - Authenticated PubSub\033[0m")

Part 2: Authenticate as a publisher

This script sends messages to the clients connected in script 1.

Now check terminal 1 to see the messages received.

EOF

curl http://tyk-gateway.localhost:8080/streams-authenticated-pubsub/post \
    -d 'Hello, Tyk streams!' \
    -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwicG9sIjoiNjZmZmI5OTMyYTRhNTEwMDAxODZkMzc0IiwiaWF0IjoxNTE2MjM5MDIyfQ.G_rM5NWQIQopOZABTLkZEfnp2XSAiN5vFyRZAOWbtFs'
