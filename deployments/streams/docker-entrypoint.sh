#!/bin/bash
set -e

echo "Starting Fake ERP Backend Servers..."
echo ""

# Start JSON ERP Server (port 8001)
echo "Starting JSON ERP Server on port 8001..."
python3 -u /app/fake_erp_servers.py json > /tmp/erp_json.log 2>&1 &
JSON_PID=$!
sleep 1

# Start XML ERP Server (port 8002)
echo "Starting XML ERP Server on port 8002..."
python3 -u /app/fake_erp_servers.py xml > /tmp/erp_xml.log 2>&1 &
XML_PID=$!
sleep 1

# Start Filtered ERP Server (port 8003)
echo "Starting Filtered ERP Server on port 8003..."
python3 -u /app/fake_erp_servers.py filtered > /tmp/erp_filtered.log 2>&1 &
FILTERED_PID=$!
sleep 1

echo ""
echo "All ERP servers started!"
echo ""
echo "JSON ERP Server:    http://localhost:8001/erp/json/receive"
echo "XML ERP Server:     http://localhost:8002/erp/xml/receive"
echo "Filtered ERP Server: http://localhost:8003/erp/filtered/receive"
echo ""

# Function to handle shutdown
cleanup() {
    echo ""
    echo "Stopping ERP servers..."
    kill $JSON_PID $XML_PID $FILTERED_PID 2>/dev/null || true
    echo "Stopped"
    exit 0
}

# Trap SIGTERM and SIGINT to handle graceful shutdown
trap cleanup SIGTERM SIGINT

# Wait for all background processes
wait