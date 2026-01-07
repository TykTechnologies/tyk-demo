#!/bin/bash

# Script to start the Web UI server for Kafka Master Data Streaming Demo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Web UI Server..."
echo ""

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed"
    echo "Please install Python 3 to run the web UI server"
    exit 1
fi

# Check if Flask is installed
if ! python3 -c "import flask" 2>/dev/null; then
    echo "Flask not found. Installing Flask..."
    pip3 install flask
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Flask"
        echo "Please install manually: pip3 install flask"
        exit 1
    fi
fi

# Check if Flask-CORS is installed (optional but recommended)
if ! python3 -c "import flask_cors" 2>/dev/null; then
    echo "Flask-CORS not found. Installing Flask-CORS (optional but recommended)..."
    pip3 install flask-cors
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to install Flask-CORS. Continuing anyway..."
        echo "The server will work, but CORS support will be disabled."
    fi
fi

# Make the server script executable
chmod +x "$SCRIPT_DIR/web_ui_server.py"

echo "Starting web UI server..."
echo ""
python3 "$SCRIPT_DIR/web_ui_server.py"

