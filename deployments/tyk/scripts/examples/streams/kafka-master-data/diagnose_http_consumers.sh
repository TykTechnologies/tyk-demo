#!/bin/bash

# Diagnostic script to troubleshoot HTTP POST consumers

echo "=== Diagnosing HTTP POST Consumers ==="
echo ""

# Check 1: Are ERP servers running?
echo "1. Checking ERP servers..."
JSON_PID=$(lsof -ti:8001 2>/dev/null)
XML_PID=$(lsof -ti:8002 2>/dev/null)
FILTERED_PID=$(lsof -ti:8003 2>/dev/null)

if [ -n "$JSON_PID" ]; then
    echo "  ✓ JSON ERP Server running on port 8001 (PID: $JSON_PID)"
else
    echo "  ✗ JSON ERP Server NOT running on port 8001"
fi

if [ -n "$XML_PID" ]; then
    echo "  ✓ XML ERP Server running on port 8002 (PID: $XML_PID)"
else
    echo "  ✗ XML ERP Server NOT running on port 8002"
fi

if [ -n "$FILTERED_PID" ]; then
    echo "  ✓ Filtered ERP Server running on port 8003 (PID: $FILTERED_PID)"
else
    echo "  ✗ Filtered ERP Server NOT running on port 8003"
fi

echo ""

# Check 2: Can ERP servers be reached directly?
echo "2. Testing direct connectivity to ERP servers..."
if curl -s -X POST http://localhost:8001/erp/json/receive -H "Content-Type: application/json" -d '{"test":"direct"}' > /dev/null 2>&1; then
    echo "  ✓ Can reach JSON ERP server at localhost:8001"
else
    echo "  ✗ CANNOT reach JSON ERP server at localhost:8001"
fi

echo ""

# Check 3: Are consumer APIs loaded in Tyk Gateway?
echo "3. Checking if consumer APIs are loaded in Tyk Gateway..."
for endpoint in "streams-master-data-json-http" "streams-master-data-xml-http" "streams-master-data-filtered-http"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://tyk-gateway.localhost:8080/$endpoint/ 2>/dev/null)
    if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "  ✓ $endpoint endpoint accessible (HTTP $HTTP_CODE)"
    else
        echo "  ✗ $endpoint endpoint NOT accessible (HTTP $HTTP_CODE)"
    fi
done

echo ""

# Check 4: Check Kafka topic for messages
echo "4. Checking Kafka topic for messages..."
echo "  (This requires Kafka to be running and accessible)"
if command -v docker &> /dev/null; then
    if docker ps | grep -q kafka; then
        echo "  ✓ Kafka container is running"
        echo "  To check messages: docker exec -it tyk-demo-kafka-1 /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic master-data-items --from-beginning --max-messages 5"
    else
        echo "  ⚠ Kafka container not found"
    fi
else
    echo "  ⚠ Docker command not available to check Kafka"
fi

echo ""

# Check 5: Test posting data
echo "5. Testing data posting..."
PRODUCER_URL="http://tyk-gateway.localhost:8080/streams-master-data/producer"
TEST_DATA='{"itemId":"DIAG-TEST-001","name":"Diagnostic Test","category":"Electronics","price":99.99}'

HTTP_CODE=$(curl -s -o /tmp/producer_diag.txt -w "%{http_code}" -X POST "$PRODUCER_URL" \
  -H "Content-Type: application/json" \
  -d "$TEST_DATA")

if [ "$HTTP_CODE" = "200" ]; then
    echo "  ✓ Data posted successfully (HTTP $HTTP_CODE)"
    echo "  Waiting 5 seconds for consumer to process..."
    sleep 5
    echo "  Check ERP server logs/terminals for receipt"
else
    echo "  ✗ Failed to post data (HTTP $HTTP_CODE)"
    cat /tmp/producer_diag.txt 2>/dev/null
fi

rm -f /tmp/producer_diag.txt

echo ""
echo "=== Diagnostic Complete ==="
echo ""
echo "Common Issues:"
echo "1. If APIs show 404: Consumer APIs not loaded - restart Tyk Dashboard"
echo "2. If ERP servers can't be reached: Check URL in API config (use host.docker.internal if Tyk is in Docker)"
echo "3. If no messages: Check Kafka is running and topic exists"
echo "4. If messages posted but not received: Check consumer API configuration and Tyk Gateway logs"
echo ""

