cat <<EOF
$(printf "\033[1mStreams - HTTP to Kakfa\033[0m")

Part 2: Consumer a Kafka topic via Tyk Streams server sent events

This example connects to Kafka via a Tyk Streams endpoint, which delivers the messages via server-sent events.

Now run part 3 of this example in a different terminal, to see the message appear here.

Waiting for messages... (Ctrl+C to stop)

EOF

curl http://tyk-gateway.localhost:8080/streams-http-to-kafka/sub
