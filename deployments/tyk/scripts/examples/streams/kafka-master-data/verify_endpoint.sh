#!/bin/bash

# Script to verify the master data producer endpoint is correctly configured

GATEWAY_URL="http://tyk-gateway.localhost:8080"
ENDPOINT="/streams-master-data/producer"

echo "=== Verifying Master Data Producer Endpoint ==="
echo ""
echo "Gateway URL: $GATEWAY_URL"
echo "Endpoint: $ENDPOINT"
echo "Full URL: $GATEWAY_URL$ENDPOINT"
echo ""

# Test 1: Check if gateway is reachable
echo "Test 1: Checking if Tyk Gateway is reachable..."
if curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/hello" > /dev/null 2>&1; then
    echo "✓ Tyk Gateway is reachable"
else
    echo "✗ Cannot reach Tyk Gateway at $GATEWAY_URL"
    exit 1
fi
echo ""

# Test 2: Check the producer endpoint with verbose output
echo "Test 2: Testing producer endpoint with POST request..."
echo "Sending test data: {\"itemId\":\"TEST-001\",\"name\":\"Test Item\"}"
echo ""

HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST "$GATEWAY_URL$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"itemId":"TEST-001","name":"Test Item","category":"Electronics","price":29.99}')

RESPONSE_BODY=$(cat /tmp/response.txt)
rm -f /tmp/response.txt

echo "HTTP Status Code: $HTTP_CODE"
echo "Response Body: $RESPONSE_BODY"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Endpoint is working correctly (HTTP 200 OK)"
    if [ -z "$RESPONSE_BODY" ] || [ "$RESPONSE_BODY" = "" ]; then
        echo "✓ Empty response body is expected for successful Streams producer requests"
    else
        echo "⚠ Response body: $RESPONSE_BODY"
    fi
elif [ "$HTTP_CODE" = "404" ]; then
    echo "✗ Endpoint not found (HTTP 404)"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check if the API definition has been imported into Tyk Dashboard"
    echo "2. Verify the listen path is configured as: /streams-master-data/"
    echo "3. Check if Tyk Gateway has been reloaded after importing the API"
    echo "4. Try listing APIs in Dashboard to confirm it exists"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "✗ Cannot connect to Gateway"
    echo "   Check if Tyk Gateway is running and accessible"
else
    echo "⚠ Unexpected HTTP status code: $HTTP_CODE"
    echo "   Response: $RESPONSE_BODY"
fi

echo ""

# Test 3: Compare with working kafka endpoint
echo "Test 3: Comparing with working Kafka Streams endpoint..."
KAFKA_ENDPOINT="/streams-kafka/post"
echo "Testing: $GATEWAY_URL$KAFKA_ENDPOINT"
KAFKA_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY_URL$KAFKA_ENDPOINT" \
  -H "Content-Type: text/plain" \
  -d "test")

if [ "$KAFKA_CODE" = "200" ]; then
    echo "✓ Kafka Streams endpoint is working ($KAFKA_CODE)"
    echo "   This confirms Tyk Gateway and Streams are functioning correctly"
else
    echo "⚠ Kafka Streams endpoint returned: $KAFKA_CODE"
fi

echo ""
echo "=== Verification Complete ==="

