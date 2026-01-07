#!/bin/bash

# Script to post canonical JSON master data from a producer system
# This simulates a producer posting master data to the HTTP ingestion endpoint

# Check if data argument is provided
if [ -z "$1" ]; then
  echo "Usage: ./post_data.sh <json-data>"
  echo "Example: ./post_data.sh '{\"itemId\":\"12345\",\"name\":\"Widget A\",\"category\":\"Electronics\",\"price\":29.99}'"
  exit 1
fi

DATA=$1

echo "Posting master data to producer endpoint..."
echo "Data: $DATA"
echo ""

# Send POST request to the producer ingestion endpoint
# This endpoint publishes to Kafka topic via Tyk Streams
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST http://tyk-gateway.localhost:8080/streams-master-data/producer \
  -H "Content-Type: application/json" \
  -d "$DATA")

RESPONSE_BODY=$(cat /tmp/response.txt 2>/dev/null)
rm -f /tmp/response.txt

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Request successful (HTTP $HTTP_CODE)"
    if [ -n "$RESPONSE_BODY" ] && [ "$RESPONSE_BODY" != "" ]; then
        echo "Response: $RESPONSE_BODY"
    fi
    echo "✓ Master data posted successfully"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "✗ Endpoint not found (HTTP $HTTP_CODE)"
    echo "Response: $RESPONSE_BODY"
    echo ""
    echo "Troubleshooting:"
    echo "1. Ensure the API definition has been imported into Tyk Dashboard"
    echo "2. Verify Tyk Gateway has been reloaded after importing"
    echo "3. Check the listen path is: /streams-master-data/"
    exit 1
else
    echo "⚠ Unexpected HTTP status: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi

