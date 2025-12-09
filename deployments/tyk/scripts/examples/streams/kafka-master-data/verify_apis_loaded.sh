#!/bin/bash

# Script to verify API definitions are loaded in Tyk Gateway

echo "=== Verifying API Definitions in Tyk Gateway ==="
echo ""

GATEWAY_URL="http://tyk-gateway.localhost:8080"

# Check if gateway is reachable
echo "1. Checking if Tyk Gateway is reachable..."
if curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/hello" > /dev/null 2>&1; then
    echo "   ✓ Tyk Gateway is reachable at $GATEWAY_URL"
else
    echo "   ✗ Cannot reach Tyk Gateway at $GATEWAY_URL"
    echo "   Please check if Tyk Gateway is running"
    exit 1
fi
echo ""

# Check Producer API
echo "2. Checking Producer API (/streams-master-data/producer)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY_URL/streams-master-data/producer" \
  -H "Content-Type: application/json" \
  -d '{"test":"data"}' 2>/dev/null)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then
    if [ "$HTTP_CODE" = "200" ]; then
        echo "   ✓ Producer API is loaded (HTTP $HTTP_CODE)"
    else
        echo "   ✗ Producer API not found (HTTP $HTTP_CODE)"
    fi
else
    echo "   ⚠ Unexpected response (HTTP $HTTP_CODE)"
fi
echo ""

# Check Consumer APIs
echo "3. Checking Consumer APIs (SSE endpoints)..."
ENDPOINTS=(
    "json:/streams-master-data-json/stream"
    "xml:/streams-master-data-xml/stream"
    "filtered:/streams-master-data-filtered/stream"
)

ALL_LOADED=true
for endpoint_info in "${ENDPOINTS[@]}"; do
    IFS=':' read -r name endpoint <<< "$endpoint_info"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 2 "$GATEWAY_URL$endpoint" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "   ✓ $name consumer API is loaded (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "   ✗ $name consumer API not found (HTTP $HTTP_CODE)"
        ALL_LOADED=false
    elif [ "$HTTP_CODE" = "000" ]; then
        echo "   ✗ $name consumer API - Connection timeout"
        ALL_LOADED=false
    else
        echo "   ⚠ $name consumer API - HTTP $HTTP_CODE"
        ALL_LOADED=false
    fi
done
echo ""

# Check data directory
echo "4. Checking API definition files in data directory..."
DATA_DIR="../../../../data/tyk-dashboard/1/apis"
if [ -d "$DATA_DIR" ]; then
    echo "   Data directory exists: $DATA_DIR"
    FILE_COUNT=$(ls -1 "$DATA_DIR"/api-streams-master-data*.json 2>/dev/null | wc -l | tr -d ' ')
    if [ "$FILE_COUNT" -gt 0 ]; then
        echo "   ✓ Found $FILE_COUNT API definition file(s)"
        echo "   Files:"
        ls -1 "$DATA_DIR"/api-streams-master-data*.json 2>/dev/null | sed 's|.*/||' | sed 's/^/     - /'
    else
        echo "   ✗ No API definition files found"
        echo "   Run: ./load_apis.sh"
    fi
else
    echo "   ✗ Data directory not found: $DATA_DIR"
fi
echo ""

# Summary
echo "=== Summary ==="
echo ""
if [ "$ALL_LOADED" = true ]; then
    echo "✓ All APIs appear to be loaded correctly!"
else
    echo "✗ Some APIs are not loaded"
    echo ""
    echo "To fix:"
    echo "1. Make sure API definitions are in the data directory:"
    echo "   ./load_apis.sh"
    echo ""
    echo "2. Reload Tyk Gateway:"
    echo "   - Restart Tyk Gateway service/container"
    echo "   - Or reload via Dashboard UI"
    echo "   - Or use: curl -X GET $GATEWAY_URL/tyk/reload/group"
fi
echo ""

