#!/bin/bash

# This example uses grpcurl to call a gRPC API service proxied by the Tyk gateway using HTTP/2 over TLS (h2c).
# APIs using h2c use their listen path to distinguish themselves when operating on the same port.

# Check if grpcurl is installed
if ! command -v grpcurl &> /dev/null
then
    echo "grpcurl is not installed. Please install grpcurl to proceed:"
    echo "brew install grpcurl"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO_FILE="${SCRIPT_DIR}/add.proto"

echo "Call gRPC "add" service using HTTP/2 over TLS (h2c): 1 + 2 = ?"
grpcurl -plaintext -import-path "$SCRIPT_DIR" -proto "$PROTO_FILE" -d '{"a":1,"b":2}' tyk-gateway.localhost:8080 addsvc.Add/Sum
