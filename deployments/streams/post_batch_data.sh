#!/bin/bash

# Script to post batched canonical JSON master data from producer systems
# This simulates multiple items being posted in a single batch request

# Check if file argument is provided
if [ -z "$1" ]; then
  echo "Usage: ./post_batch_data.sh <json-file>"
  echo "Example: ./post_batch_data.sh batch_items.json"
  echo ""
  echo "JSON file should contain an array of items in canonical format:"
  echo '[{"itemId":"123","name":"Item A","category":"Cat1"},{"itemId":"456","name":"Item B","category":"Cat2"}]'
  exit 1
fi

BATCH_FILE=$1

if [ ! -f "$BATCH_FILE" ]; then
  echo "Error: File $BATCH_FILE not found"
  exit 1
fi

echo "Posting batched master data to producer endpoint..."
echo "File: $BATCH_FILE"
echo ""

# Send POST request with batched data
# Note: Uses the same /producer endpoint - Tyk Streams can handle both single items and arrays
HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" -X POST http://tyk-gateway.localhost:8080/streams-master-data/producer \
  -H "Content-Type: application/json" \
  -d "@$BATCH_FILE")

RESPONSE_BODY=$(cat /tmp/response.txt 2>/dev/null)
rm -f /tmp/response.txt

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Request successful (HTTP $HTTP_CODE)"
    if [ -n "$RESPONSE_BODY" ] && [ "$RESPONSE_BODY" != "" ]; then
        echo "Response: $RESPONSE_BODY"
    fi
    echo "✓ Batched master data posted successfully"
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

