#!/bin/bash

# Script to verify consumer endpoints are configured

echo "=== Verifying Consumer Endpoints ==="
echo ""

ENDPOINTS=(
    "/streams-master-data-json/stream"
    "/streams-master-data-xml/stream"
    "/streams-master-data-filtered/stream"
)

GATEWAY_URL="http://tyk-gateway.localhost:8080"

for endpoint in "${ENDPOINTS[@]}"; do
    echo "Testing: $endpoint"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 2 "$GATEWAY_URL$endpoint")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "  ✓ Working (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "  ✗ Not found (HTTP $HTTP_CODE) - API definition not loaded"
    elif [ "$HTTP_CODE" = "000" ]; then
        echo "  ✗ Timeout/Connection failed - Gateway might not be running"
    else
        echo "  ⚠ HTTP $HTTP_CODE"
    fi
    echo ""
done

echo "=== Troubleshooting ==="
echo ""
echo "If all endpoints show 404:"
echo "1. Consumer API definitions need to be imported into Tyk Dashboard"
echo "2. After importing, restart Tyk Dashboard or reload Gateway"
echo "3. Check that the API definitions are in: data/tyk-dashboard/1/apis/"
echo ""
echo "Files that should exist:"
echo "  - api-streams-master-data-consumer-json.json"
echo "  - api-streams-master-data-consumer-xml.json"
echo "  - api-streams-master-data-consumer-filtered.json"
echo ""
echo "Import via Dashboard UI:"
echo "  APIs → Add New API → Import OpenAPI/AsyncAPI Definition"
echo ""

