#!/bin/bash

# Check if messages are in Kafka topic

echo "=== Checking Kafka Topic for Messages ==="
echo ""

KAFKA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -i kafka | head -1)

if [ -z "$KAFKA_CONTAINER" ]; then
    echo "✗ Kafka container not found"
    exit 1
fi

echo "Kafka container: $KAFKA_CONTAINER"
echo "Topic: master-data-items"
echo ""
echo "Checking for messages (this will show messages and exit)..."
echo ""

docker exec $KAFKA_CONTAINER /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic master-data-items \
  --from-beginning \
  --max-messages 5 \
  --timeout-ms 5000 2>&1 | head -10

echo ""
echo "If you see messages above, they are in Kafka."
echo "If you see nothing, try posting a message first with ./post_data.sh"

