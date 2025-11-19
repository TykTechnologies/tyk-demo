#!/bin/bash

# Troubleshooting script for HTTP POST consumers

echo "=== Troubleshooting HTTP POST Consumers ==="
echo ""

# Step 1: Check if messages are in Kafka
echo "1. Checking Kafka topic for messages..."
echo "   (This will show recent messages)"
echo ""
docker exec $(docker ps --format "{{.Names}}" | grep -i kafka | head -1) \
  /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic master-data-items \
  --from-beginning \
  --max-messages 3 \
  --timeout-ms 3000 2>&1 | head -10

echo ""
echo ""

# Step 2: Test ERP servers directly
echo "2. Testing ERP servers directly..."
for port in 8001 8002 8003; do
    echo -n "   Port $port: "
    if curl -s -X POST http://localhost:$port/erp/json/receive -H "Content-Type: application/json" -d '{"test":"direct"}' > /dev/null 2>&1; then
        echo "✓ Reachable"
    else
        echo "✗ NOT reachable"
    fi
done

echo ""
echo ""

# Step 3: Post a test message
echo "3. Posting test message to producer..."
TEST_DATA='{"itemId":"TROUBLESHOOT-001","name":"Troubleshoot Test","category":"Electronics","price":49.99,"status":"active"}'
HTTP_CODE=$(curl -s -o /tmp/test_response.txt -w "%{http_code}" -X POST http://tyk-gateway.localhost:8080/streams-master-data/producer \
  -H "Content-Type: application/json" \
  -d "$TEST_DATA")

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✓ Message posted successfully (HTTP $HTTP_CODE)"
    echo "   Waiting 10 seconds for consumer processing..."
    sleep 10
    echo "   Check ERP server terminals/logs for receipt"
else
    echo "   ✗ Failed to post message (HTTP $HTTP_CODE)"
    cat /tmp/test_response.txt
fi

rm -f /tmp/test_response.txt

echo ""
echo ""

# Step 4: Recommendations
echo "=== Troubleshooting Steps ==="
echo ""
echo "If messages are in Kafka but not reaching ERP servers:"
echo ""
echo "1. Check Tyk Gateway logs for consumer errors:"
echo "   docker logs $(docker ps --format '{{.Names}}' | grep -i gateway | head -1) | grep -i stream"
echo ""
echo "2. Verify consumer APIs are active in Tyk Dashboard"
echo ""
echo "3. Check if output format is correct - Tyk Streams uses Benthos format"
echo "   Current format uses: http_request"
echo "   Might need: http_client (Benthos format)"
echo ""
echo "4. Verify connectivity from Docker to host:"
echo "   The URL uses: host.docker.internal:8001"
echo "   On macOS, this should work, but verify in Docker logs"
echo ""
echo "5. Check consumer group offsets:"
echo "   The consumers might have already consumed messages"
echo "   Try posting new messages after starting the consumers"
echo ""

