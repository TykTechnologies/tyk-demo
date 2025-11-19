#!/bin/bash

# Test what Benthos is actually sending by checking the logs
# and comparing with direct curl test

echo "=== Testing HTTP POST Format ==="
echo ""

echo "1. Posting a test message to Kafka via producer..."
cd /Users/lheritage/tykdemo/tyk-demo/deployments/tyk/scripts/examples/streams/kafka-master-data
./post_data.sh '{"itemId":"FORMAT-TEST-001","name":"Format Test","category":"Electronics","price":99.99,"status":"active"}'

echo ""
echo "2. Waiting 3 seconds for consumer to process..."
sleep 3

echo ""
echo "3. Check the ERP server terminal output for:"
echo "   - Request headers received"
echo "   - Body content and length"
echo "   - Any errors or warnings"
echo ""
echo "4. If you see 'EOF' errors in Tyk Gateway logs but nothing in ERP logs,"
echo "   the request might not be reaching the ERP server at all."
echo ""
echo "5. Try direct curl test:"
echo "   curl -X POST http://127.0.0.1:8001/erp/json/receive \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"itemId\":\"DIRECT-TEST\",\"name\":\"Direct Test\"}'"
echo ""

