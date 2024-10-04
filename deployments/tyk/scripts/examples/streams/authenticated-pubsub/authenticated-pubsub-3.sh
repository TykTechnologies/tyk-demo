echo "Streams - Authenticated PubSub"
echo "Part 3: Authentication failure"
echo "This script attempts to send an unauthenticated message to the auth-protected endpoint. This results in the request being rejected."

curl http://tyk-gateway.localhost:8080/streams-authenticated-pubsub/pub \
    -d 'Hello, Tyk streams!'
