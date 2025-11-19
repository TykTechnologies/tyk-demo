#!/bin/bash

# Test if Tyk Gateway can reach the ERP servers
# This simulates what Tyk Streams would do

echo "=== Testing Connectivity from Tyk Gateway Perspective ==="
echo ""

# Test 1: Try from host (localhost)
echo "1. Testing from host (localhost):8001..."
if curl -s -X POST http://localhost:8001/erp/json/receive \
  -H "Content-Type: application/json" \
  -d '{"itemId":"TEST","name":"Test"}' > /dev/null 2>&1; then
    echo "  ✓ localhost:8001 is reachable from host"
else
    echo "  ✗ localhost:8001 NOT reachable from host"
fi

echo ""

# Test 2: Try host.docker.internal (if Gateway is in Docker)
echo "2. Testing host.docker.internal:8001..."
if curl -s -X POST http://host.docker.internal:8001/erp/json/receive \
  -H "Content-Type: application/json" \
  -d '{"itemId":"TEST","name":"Test"}' > /dev/null 2>&1; then
    echo "  ✓ host.docker.internal:8001 is reachable"
else
    echo "  ✗ host.docker.internal:8001 NOT reachable (expected if running on host)"
fi

echo ""

# Test 3: Check if Tyk Gateway is in Docker
echo "3. Checking Tyk Gateway container..."
if docker ps 2>/dev/null | grep -q tyk-gateway; then
    echo "  ✓ Tyk Gateway is running in Docker"
    echo "  → Should use: host.docker.internal:8001"
    
    # Test from inside Docker container
    echo "  Testing from inside container..."
    docker exec tyk-demo-gateway-1 curl -s -X POST http://host.docker.internal:8001/erp/json/receive \
      -H "Content-Type: application/json" \
      -d '{"itemId":"TEST","name":"Test"}' 2>&1 | head -3
else
    echo "  ⚠ Tyk Gateway may not be in Docker"
    echo "  → Should use: localhost:8001"
fi

echo ""
echo "=== Configuration Check ==="
echo ""
echo "Current API configuration uses:"
grep -A 2 '"http_request"' /Users/lheritage/tykdemo/tyk-demo/deployments/tyk/data/tyk-dashboard/1/apis/api-streams-master-data-consumer-json-http.json | grep url

echo ""
echo "Recommendation:"
echo "  - If Tyk Gateway is in Docker: Use host.docker.internal:8001 (current)"
echo "  - If Tyk Gateway is on host: Use localhost:8001"

