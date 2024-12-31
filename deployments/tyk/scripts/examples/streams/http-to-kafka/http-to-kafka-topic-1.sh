cat <<EOF
$(printf "\033[1mStreams - HTTP to Kakfa\033[0m")

Part 1: Consume a Kafka topic via the Kafka console consumer

This example connects to the 'tyk-streams-example' Kafka topic directly using the standard Kafka console consumer.

Now run part 2 in a different terminal, to connect to Kafka using Tyk Streams.

Waiting for messages... (Ctrl+C to stop)

EOF

docker exec -it tyk-demo-kafka-1 /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic tyk-streams-example --from-beginning
