#!/bin/bash

# Automated test script for Kafka master data streaming example
# This tests the producer-to-consumer flow with different consumer types

# Variables
PRODUCER_URL="http://tyk-gateway.localhost:8080/streams-master-data/producer"
JSON_CONSUMER_URL="http://tyk-gateway.localhost:8080/streams-master-data-json/stream"
XML_CONSUMER_URL="http://tyk-gateway.localhost:8080/streams-master-data-xml/stream"
FILTERED_CONSUMER_URL="http://tyk-gateway.localhost:8080/streams-master-data-filtered/stream"

TIMEOUT=15
RESPONSE_FILE=$(mktemp)

# Test data
TEST_ITEM_1='{"itemId":"TEST-001","name":"Test Widget","category":"Electronics","price":49.99,"description":"A test widget"}'
TEST_ITEM_2='{"itemId":"TEST-002","name":"Test Gadget","category":"Accessories","price":19.99,"description":"A test gadget"}'
TEST_ITEM_3='{"itemId":"TEST-003","name":"Test Device","category":"Electronics","price":99.99,"description":"A test device"}'

# Function to clean up background listeners
cleanup() {
    if [[ -n "$json_listener_pid" ]]; then
        kill "$json_listener_pid" 2>/dev/null || true
    fi
    if [[ -n "$xml_listener_pid" ]]; then
        kill "$xml_listener_pid" 2>/dev/null || true
    fi
    if [[ -n "$filtered_listener_pid" ]]; then
        kill "$filtered_listener_pid" 2>/dev/null || true
    fi
    rm -f "$RESPONSE_FILE"
}
trap cleanup EXIT

echo "=== Kafka Master Data Streaming Test ==="
echo ""

# Test 1: JSON Consumer
echo "Test 1: Testing JSON Consumer..."
echo "Posting test item: $TEST_ITEM_1"

# Start JSON consumer listener
curl -N "$JSON_CONSUMER_URL" > "$RESPONSE_FILE.json" 2>&1 & json_listener_pid=$!
sleep 2

# Post data
if ! curl -s -X POST "$PRODUCER_URL" -H "Content-Type: application/json" -d "$TEST_ITEM_1" >/dev/null; then
    echo "✗ Failed to post data"
    exit 1
fi

# Wait for message
end_time=$((SECONDS + TIMEOUT))
found=false
while [[ $SECONDS -lt $end_time ]]; do
    if grep -q "TEST-001" "$RESPONSE_FILE.json" 2>/dev/null; then
        echo "✓ JSON Consumer received message"
        found=true
        break
    fi
    sleep 1
done

if [ "$found" = false ]; then
    echo "✗ JSON Consumer did not receive message within timeout"
fi

# Clean up for next test
kill "$json_listener_pid" 2>/dev/null || true
sleep 1

# Test 2: XML Consumer
echo ""
echo "Test 2: Testing XML Consumer with transformation..."
echo "Posting test item: $TEST_ITEM_2"

# Start XML consumer listener
curl -N "$XML_CONSUMER_URL" > "$RESPONSE_FILE.xml" 2>&1 & xml_listener_pid=$!
sleep 2

# Post data
if ! curl -s -X POST "$PRODUCER_URL" -H "Content-Type: application/json" -d "$TEST_ITEM_2" >/dev/null; then
    echo "✗ Failed to post data"
    exit 1
fi

# Wait for XML message
end_time=$((SECONDS + TIMEOUT))
found=false
while [[ $SECONDS -lt $end_time ]]; do
    if grep -q "TEST-002\|<item\|<itemId>" "$RESPONSE_FILE.xml" 2>/dev/null; then
        echo "✓ XML Consumer received transformed message"
        found=true
        break
    fi
    sleep 1
done

if [ "$found" = false ]; then
    echo "✗ XML Consumer did not receive message within timeout"
fi

# Clean up for next test
kill "$xml_listener_pid" 2>/dev/null || true
sleep 1

# Test 3: Filtered Consumer
echo ""
echo "Test 3: Testing Filtered Consumer..."
echo "Posting test item: $TEST_ITEM_3 (Electronics category)"

# Start filtered consumer listener
curl -N "$FILTERED_CONSUMER_URL" > "$RESPONSE_FILE.filtered" 2>&1 & filtered_listener_pid=$!
sleep 2

# Post data
if ! curl -s -X POST "$PRODUCER_URL" -H "Content-Type: application/json" -d "$TEST_ITEM_3" >/dev/null; then
    echo "✗ Failed to post data"
    exit 1
fi

# Wait for filtered message
end_time=$((SECONDS + TIMEOUT))
found=false
while [[ $SECONDS -lt $end_time ]]; do
    if grep -q "TEST-003\|Electronics" "$RESPONSE_FILE.filtered" 2>/dev/null; then
        echo "✓ Filtered Consumer received message"
        found=true
        break
    fi
    sleep 1
done

if [ "$found" = false ]; then
    echo "✗ Filtered Consumer did not receive message within timeout"
fi

kill "$filtered_listener_pid" 2>/dev/null || true

echo ""
echo "=== Test Complete ==="

