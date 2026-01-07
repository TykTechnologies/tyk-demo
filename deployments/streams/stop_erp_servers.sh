#!/bin/bash

# Script to stop all fake ERP servers

echo "Stopping Fake ERP Backend Servers..."

# Find and kill processes running on ports 8001, 8002, 8003
for port in 8001 8002 8003; do
    PID=$(lsof -ti:$port 2>/dev/null)
    if [ -n "$PID" ]; then
        echo "Stopping server on port $port (PID: $PID)..."
        kill $PID 2>/dev/null
    else
        echo "No server found on port $port"
    fi
done

# Also try to kill by process name
pkill -f "fake_erp_servers.py" 2>/dev/null

echo "Done!"

