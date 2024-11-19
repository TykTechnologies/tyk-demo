#!/bin/bash

# This example uses grpcurl to call different TLS API definitions that are configured to listen on the same port (9005).
# The Gateway uses the SNI data to find the correct API definition based on its custom domain (tls-multiplex-1.localhost / tls-multiplex-2.localhost).

source scripts/common.sh

check_for_grpcurl

echo "Sending gRPC request via tls-multiplex-1.localhost: this request should work, as the API definition is active"
grpcurl -insecure -d '{"greeting":"Maus"}' tls-multiplex-1.localhost:9005 hello.HelloService.SayHello
echo "Sending gRPC request via tls-multiplex-2.localhost: this request should fail by timeout, as the API definition target URL does not exist"
grpcurl -insecure -d '{"greeting":"Ralph"}' tls-multiplex-2.localhost:9005 hello.HelloService.SayHello
