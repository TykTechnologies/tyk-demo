#!/bin/bash

# Test script for HTTP POST consumers
# This tests the flow: Producer -> Kafka -> Consumer -> HTTP POST -> ERP

PRODUCER_URL="http://tyk-gateway.localhost:8080/streams-master-data/producer"
TEST_ITEM='{"itemId":"HTTP-TEST-001","name":"HTTP Test Widget","category":"Electronics","price":49.99,"description":"Test item for HTTP POST consumer","status":"active","lastUpdated":"2024-01-15T10:30:00Z"}'

echo "=== Testing HTTP POST Consumers ==="
echo ""

# Check if ERP servers are running
echo "Checking ERP servers..."
JSON_RUNNING=$(lsof -ti:8001 2>/dev/null)
XML_RUNNING=$(lsof -ti:8002 2>/dev/null)
FILTERED_RUNNING=$(lsof -ti:8003 2>/dev/null)

if [ -z "$JSON_RUNNING" ]; then
    echo "⚠ JSON ERP Server (port 8001) is not running"
    echo "   Start it with: python3 fake_erp_servers.py json"
fi

if [ -z "$XML_RUNNING" ]; then
    echo "⚠ XML ERP Server (port 8002) is not running"
    echo "   Start it with: python3 fake_erp_servers.py xml"
fi

if [ -z "$FILTERED_RUNNING" ]; then
    echo "⚠ Filtered ERP Server (port 8003) is not running"
    echo "   Start it with: python3 fake_erp_servers.py filtered"
fi

if [ -z "$JSON_RUNNING" ] || [ -z "$XML_RUNNING" ] || [ -z "$FILTERED_RUNNING" ]; then
    echo ""
    echo "Please start all ERP servers before testing."
    echo "Or run: ./start_erp_servers.sh"
    exit 1
fi

echo "✓ All ERP servers are running"
echo ""

# Test 1: JSON Consumer
echo "Test 1: Posting data to trigger JSON HTTP POST consumer..."
echo "Test item: $TEST_ITEM"
echo ""

HTTP_CODE=$(curl -s -o /tmp/producer_response.txt -w "%{http_code}" -X POST "$PRODUCER_URL" \
  -H "Content-Type: application/json" \
  -d "$TEST_ITEM")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Data posted successfully (HTTP $HTTP_CODE)"
    echo "  Check JSON ERP server logs for receipt confirmation"
    echo "  Log: /tmp/erp_json.log or tail the JSON ERP server output"
else
    echo "✗ Failed to post data (HTTP $HTTP_CODE)"
fi

echo ""
sleep 2

# Test 2: XML Consumer (same item, should trigger XML transformation)
echo "Test 2: Posting data to trigger XML HTTP POST consumer..."
TEST_ITEM_XML='{"itemId":"HTTP-TEST-002","name":"HTTP Test Device","category":"Electronics","price":99.99,"description":"Test item for XML consumer","status":"active","lastUpdated":"2024-01-15T10:31:00Z"}'

HTTP_CODE=$(curl -s -o /tmp/producer_response2.txt -w "%{http_code}" -X POST "$PRODUCER_URL" \
  -H "Content-Type: application/json" \
  -d "$TEST_ITEM_XML")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Data posted successfully (HTTP $HTTP_CODE)"
    echo "  Check XML ERP server logs for receipt confirmation"
    echo "  Log: /tmp/erp_xml.log or tail the XML ERP server output"
else
    echo "✗ Failed to post data (HTTP $HTTP_CODE)"
fi

echo ""
sleep 2

# Test 3: Filtered Consumer (Electronics category should pass through)
echo "Test 3: Posting Electronics item to trigger Filtered HTTP POST consumer..."
TEST_ITEM_FILTERED='{"itemId":"HTTP-TEST-003","name":"HTTP Electronics Item","category":"Electronics","price":29.99,"description":"Test item for filtered consumer","status":"active","lastUpdated":"2024-01-15T10:32:00Z"}'

HTTP_CODE=$(curl -s -o /tmp/producer_response3.txt -w "%{http_code}" -X POST "$PRODUCER_URL" \
  -H "Content-Type: application/json" \
  -d "$TEST_ITEM_FILTERED")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Data posted successfully (HTTP $HTTP_CODE)"
    echo "  Check Filtered ERP server logs for receipt confirmation"
    echo "  Log: /tmp/erp_filtered.log or tail the Filtered ERP server output"
else
    echo "✗ Failed to post data (HTTP $HTTP_CODE)"
fi

echo ""
sleep 1

# Test 4: Filtered Consumer (Non-Electronics should be filtered out)
echo "Test 4: Posting non-Electronics item (should NOT trigger Filtered consumer)..."
TEST_ITEM_NON_ELECTRONICS='{"itemId":"HTTP-TEST-004","name":"HTTP Accessory Item","category":"Accessories","price":19.99,"description":"Non-Electronics item - should be filtered out","status":"active","lastUpdated":"2024-01-15T10:33:00Z"}'

HTTP_CODE=$(curl -s -o /tmp/producer_response4.txt -w "%{http_code}" -X POST "$PRODUCER_URL" \
  -H "Content-Type: application/json" \
  -d "$TEST_ITEM_NON_ELECTRONICS")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Data posted successfully (HTTP $HTTP_CODE)"
    echo "  This item should NOT appear in Filtered ERP server (category: Accessories)"
else
    echo "✗ Failed to post data (HTTP $HTTP_CODE)"
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "Check ERP server outputs to verify messages were received via HTTP POST"
echo ""
rm -f /tmp/producer_response*.txt

