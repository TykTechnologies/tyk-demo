#!/bin/bash

# Script to copy API definitions to Tyk Dashboard data directory and reload

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DATA_DIR="../../../../data/tyk-dashboard/1/apis"

echo "=== Loading API Definitions into Tyk Gateway ==="
echo ""

# Check if data directory exists
if [ ! -d "$DATA_DIR" ]; then
    echo "✗ Error: Data directory not found: $DATA_DIR"
    echo "Please check the path to your Tyk Dashboard data directory"
    exit 1
fi

echo "Data directory: $(cd "$DATA_DIR" && pwd)"
echo ""

# Copy all API definition files
echo "Copying API definitions..."
cp api-streams-master-data*.json "$DATA_DIR/"

if [ $? -eq 0 ]; then
    echo "✓ Successfully copied API definitions"
    echo ""
    
    # List copied files
    echo "Copied files:"
    ls -lh "$DATA_DIR"/api-streams-master-data*.json | awk '{print "  - " $9 " (" $5 ")"}'
    echo ""
    
    echo "=== Next Steps ==="
    echo ""
    echo "The API definitions have been copied, but you need to reload Tyk Gateway for them to take effect."
    echo ""
    echo "Option 1: Restart Tyk Gateway"
    echo "  docker restart <tyk-gateway-container-name>"
    echo "  # OR"
    echo "  sudo systemctl restart tyk-gateway"
    echo ""
    echo "Option 2: Reload via Dashboard"
    echo "  1. Log into Tyk Dashboard"
    echo "  2. Go to APIs → Select each API → Click 'Save' (this triggers reload)"
    echo ""
    echo "Option 3: Hot Reload (if supported)"
    echo "  curl -X GET http://tyk-gateway.localhost:8080/tyk/reload/group"
    echo ""
    echo "After reloading, verify with:"
    echo "  ./verify_apis_loaded.sh"
    echo ""
else
    echo "✗ Failed to copy API definitions"
    exit 1
fi

