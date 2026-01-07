#!/bin/bash

# Script to start all fake ERP servers
# Each server runs in the background so you can start all three

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Fake ERP Backend Servers..."
echo ""

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed"
    echo "Please install Python 3 to run the ERP servers"
    exit 1
fi

# Start JSON ERP Server (port 8001)
echo "Starting JSON ERP Server on port 8001..."
python3 -u "$SCRIPT_DIR/fake_erp_servers.py" json > /tmp/erp_json.log 2>&1 &
JSON_PID=$!
echo "  PID: $JSON_PID"
echo "  Log: /tmp/erp_json.log"
sleep 1

# Start XML ERP Server (port 8002)
echo "Starting XML ERP Server on port 8002..."
python3 -u "$SCRIPT_DIR/fake_erp_servers.py" xml > /tmp/erp_xml.log 2>&1 &
XML_PID=$!
echo "  PID: $XML_PID"
echo "  Log: /tmp/erp_xml.log"
sleep 1

# Start Filtered ERP Server (port 8003)
echo "Starting Filtered ERP Server on port 8003..."
python3 -u "$SCRIPT_DIR/fake_erp_servers.py" filtered > /tmp/erp_filtered.log 2>&1 &
FILTERED_PID=$!
echo "  PID: $FILTERED_PID"
echo "  Log: /tmp/erp_filtered.log"
sleep 1

echo ""
echo "All ERP servers started!"
echo ""
echo "To view logs:"
echo "  JSON ERP:     tail -f /tmp/erp_json.log"
echo "  XML ERP:      tail -f /tmp/erp_xml.log"
echo "  Filtered ERP: tail -f /tmp/erp_filtered.log"
echo ""
echo "To stop servers:"
echo "  kill $JSON_PID $XML_PID $FILTERED_PID"
echo ""
echo "Or run: ./stop_erp_servers.sh"
echo ""

# Wait for user interrupt
trap "echo ''; echo 'Stopping ERP servers...'; kill $JSON_PID $XML_PID $FILTERED_PID 2>/dev/null; echo 'Stopped'; exit" INT

# Keep script running
while true; do
    sleep 1
done

