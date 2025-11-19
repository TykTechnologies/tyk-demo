#!/bin/bash

# Script to simulate an XML consumer endpoint
# This listens for HTTP POST requests from Tyk Streams (Kafka consumer)
# representing a downstream system that requires XML format conversion

echo "Starting XML Consumer Endpoint (Consumer Group: xml-consumers)"
echo "This simulates an ERP system that requires XML format"
echo "Tyk Streams will transform JSON to XML before sending"
echo "Listening on: http://tyk-gateway.localhost:8080/streams-master-data-xml/stream"
echo ""
echo "Press CTRL+C to quit"
echo ""

# This endpoint receives POST requests from Tyk Streams with XML-transformed messages
# In a real scenario, this would be your ERP system's HTTP endpoint
curl -N http://tyk-gateway.localhost:8080/streams-master-data-xml/stream

