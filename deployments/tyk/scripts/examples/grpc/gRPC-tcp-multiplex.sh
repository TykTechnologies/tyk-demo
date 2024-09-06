#!/bin/bash

# This example uses grpcurl to call a gRPC API service proxied by the Tyk gateway using TLS.
# The Gateway is listening for both APIs on the same port (9005), so it uses the SNI data to find the correct API definition based on its custom domain (tls-multiplex-1.localhost / tls-multiplex-2.localhost).

source scripts/common.sh

check_for_grpcurl

echo "Sending gRPC request via tls-multiplex-1.localhost"
grpcurl -insecure -d '{"greeting":"Maus"}' tls-multiplex-1.localhost:9005 hello.HelloService.SayHello
echo "Sending gRPC request via tls-multiplex-2.localhost"
grpcurl -insecure -d '{"greeting":"Ralph"}' tls-multiplex-2.localhost:9005 hello.HelloService.SayHello
