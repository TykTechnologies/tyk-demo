echo "Streams - Authenticated PubSub"
echo "Part 3: Authenticate as a publisher"
echo "This script sends messages to the clients connected in script 1 - check its terminal to see the messages received."

curl http://tyk-gateway.localhost:8080/streams-authenticated-pubsub/pub \
    -d 'Hello, Tyk streams!' \
    -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwicG9sIjoiNjZmZmI5OTMyYTRhNTEwMDAxODZkMzc0IiwiaWF0IjoxNTE2MjM5MDIyfQ.G_rM5NWQIQopOZABTLkZEfnp2XSAiN5vFyRZAOWbtFs'
