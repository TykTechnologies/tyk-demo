echo "Streams - HTTP to Kakfa"
echo "Part 1: Consuming the Kafka topic"
echo "This script connects to the 'tyk-streams-example' Kafka topic and waits for messages."
echo "Now run part two of this example in a different terminal, to see the message appear here."
docker exec -it tyk-demo-kafka-1 /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic tyk-streams-example --from-beginning
