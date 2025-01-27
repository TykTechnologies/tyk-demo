echo "Consuming Kafka topic using Kakfa CLI... (CTRL+C to quit)"

docker exec -it tyk-demo-kafka-1 /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic tyk-streams-example --from-beginning