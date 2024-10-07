echo "Streams - HTTP to Kakfa"
echo "Part 2: Consumer a Kafka topic via Tyk Streams server sent events"
echo "This example connects to Kafka via a Tyk Streams endpoint, which delivers the messages via server-sent events."
echo "Now run part three of this example in a different terminal, to see the message appear here."
curl http://tyk-gateway.localhost:8080/streams-http-to-kafka/sub
