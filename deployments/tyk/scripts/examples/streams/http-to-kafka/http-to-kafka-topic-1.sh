echo "Streams - HTTP to Kakfa"
echo "Part 1: Consume a Kafka topic via the Kafka console consumer"
echo "This example connects to the 'tyk-streams-example' Kafka topic and waits for messages."
echo "Now run part two in a different terminal, to connect to Kafka using Tyk Streams."
docker exec -it tyk-demo-kafka-1 /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic tyk-streams-example --from-beginning
