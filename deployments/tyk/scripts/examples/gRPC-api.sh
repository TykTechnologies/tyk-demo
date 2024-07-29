#!/bin/bash

# This example uses grpcurl to call gRPC API services proxied by the Tyk gateway.
# Port 9002 proxies to insecure gRPC (note -plaintext flag)
# Port 9003 proxies to secure gRPC (note -insecure flag, due to self-signed certificate)

# Check if grpcurl is installed
if ! command -v grpcurl &> /dev/null
then
    echo "grpcurl is not installed. Please install grpcurl to proceed:"
    echo "brew install grpcurl"
    exit 1
fi

echo "Available services:"
grpcurl -plaintext tyk-gateway.localhost:9002 list

echo -e "\nExample 1: ralph greeting - using gRPC without TLS"
grpcurl -plaintext -d '{"greeting":"ralph"}' tyk-gateway.localhost:9002 hello.HelloService.SayHello

echo -e "\nExample 2: maus greeting - using gRPC with TLS"
grpcurl -insecure -d '{"greeting":"maus"}' tyk-gateway.localhost:9003 hello.HelloService.SayHello

echo -e "\nExample 3: maths - 1 + 2 = ?"
grpcurl -plaintext -d '{"a":1,"b":2}' tyk-gateway.localhost:9002 addsvc.Add.Sum
