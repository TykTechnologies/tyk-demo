echo "Streams - HTTP to Kakfa"
echo "Part 2: Send messages to the Kafka topic via HTTP"
echo "This sends a messages to the 'tyk-streams-example' Kafka topic via an HTTP request that is handled by Tyk."
echo "Now check the first terminal to see that the message 'Hello, Tyk streams!' has appeared."
curl -X POST http://tyk-gateway.localhost:8080/streams-http-to-kafka/post -d 'Hello, Tyk streams!'
