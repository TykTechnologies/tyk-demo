
#!/bin/bash

# This example uses grpcurl to call a gRPC API service proxied by the Tyk gateway using HTTP/2 over TLS (h2c).
# Run the script from the directory it is located, as it references the hello.proto file that is also stored there.

# Check if grpcurl is installed
if ! command -v grpcurl &> /dev/null
then
    echo "grpcurl is not installed. Please install grpcurl to proceed:"
    echo "brew install grpcurl"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO_FILE="${SCRIPT_DIR}/hello.proto"

echo "Call gRPC service using HTTP/2 over TLS (h2c)"
grpcurl -plaintext -import-path "$SCRIPT_DIR" -proto "$PROTO_FILE" -d '{"greeting":"ralph"}' tyk-gateway.localhost:8080 hello.HelloService/SayHello
