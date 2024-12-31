cat <<EOF
$(printf "\033[1mStreams - HTTP to Kakfa\033[0m")

Part 3: Send messages to the Kafka topic via HTTP

This sends a messages to the 'tyk-streams-example' Kafka topic via an HTTP request that is handled by Tyk.

Now check the first and second terminals to see that the message 'Hello, Tyk Streams!' has appeared.

EOF

curl -X POST http://tyk-gateway.localhost:8080/streams-http-to-kafka/post -d 'Hello, Tyk Streams!'
