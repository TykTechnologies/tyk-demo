#!/bin/bash

# Test if Docker container can reach host.docker.internal

echo "=== Testing Docker to Host Connectivity ==="
echo ""

GATEWAY_CONTAINER=$(docker ps --format "{{.Names}}" | grep -i gateway | head -1)

if [ -z "$GATEWAY_CONTAINER" ]; then
    echo "✗ Gateway container not found"
    exit 1
fi

echo "Gateway container: $GATEWAY_CONTAINER"
echo ""

echo "Testing connectivity from container to host..."
echo ""

# Test DNS resolution
echo "1. Testing DNS resolution of host.docker.internal..."
docker exec $GATEWAY_CONTAINER nslookup host.docker.internal 2>&1 | head -5 || echo "  nslookup not available, trying ping..."

# Test ping
echo ""
echo "2. Testing ping to host.docker.internal..."
docker exec $GATEWAY_CONTAINER ping -c 1 host.docker.internal 2>&1 | head -3 || echo "  ping failed or not available"

# Test HTTP connection (if wget/curl available)
echo ""
echo "3. Testing HTTP connection to ERP server..."
echo "   (This may fail if curl/wget not in container, but that's OK)"
docker exec $GATEWAY_CONTAINER wget -O- --timeout=2 http://host.docker.internal:8001/erp/json/receive 2>&1 | head -5 || \
docker exec $GATEWAY_CONTAINER curl -s --connect-timeout 2 http://host.docker.internal:8001/erp/json/receive 2>&1 | head -3 || \
echo "  HTTP test tools not available in container"

echo ""
echo "=== Summary ==="
echo "If DNS/ping works but HTTP doesn't, the issue might be:"
echo "  1. host.docker.internal resolves but port isn't reachable"
echo "  2. Firewall blocking Docker-to-host connections"
echo "  3. The ERP servers need to bind to 0.0.0.0 instead of localhost"
echo ""

