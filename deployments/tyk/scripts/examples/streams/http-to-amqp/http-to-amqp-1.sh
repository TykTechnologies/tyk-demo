cat <<EOF
$(printf "\033[1mStreams - HTTP to AMQP\033[0m")

Part 1: Listen for messages

Once connected, run part 2 of this example in a different terminal. The messages sent by part 2 will appear here.
Tyk enables messages in an AMQP queue to be consumed using server-sent events.

Waiting for messages... (Ctrl+C to stop)

EOF

curl -N http://tyk-gateway.localhost:8080/streams-http-to-amqp/sse