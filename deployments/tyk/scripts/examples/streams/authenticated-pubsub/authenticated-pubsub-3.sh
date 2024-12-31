cat <<EOF
$(printf "\033[1mStreams - Authenticated PubSub\033[0m")

Part 3: Authentication failure

This script attempts to send an unauthenticated message to the auth-protected endpoint. This results in the request being rejected.

EOF

curl http://tyk-gateway.localhost:8080/streams-authenticated-pubsub/post \
    -d 'Hello, Tyk streams!'
