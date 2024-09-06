#!/bin/bash

# This example uses grpcurl to call gRPC API services proxied by the Tyk gateway using TCP.
# Port 9002 proxies to insecure gRPC (note -plaintext flag)
# Port 9003 proxies to secure gRPC (note -insecure flag, due to self-signed certificate)

source scripts/common.sh

check_for_grpcurl

echo "Available services:"
grpcurl -plaintext tyk-gateway.localhost:9002 list

echo -e "\nExample 1: Ralph greeting - using gRPC without TLS"
grpcurl -plaintext -d '{"greeting":"Ralph"}' tyk-gateway.localhost:9002 hello.HelloService.SayHello

echo -e "\nExample 2: Maus greeting - using gRPC with TLS"
grpcurl -insecure -d '{"greeting":"Maus"}' tyk-gateway.localhost:9003 hello.HelloService.SayHello

echo -e "\nExample 3: What is 1 + 2?"
grpcurl -plaintext -d '{"a":1,"b":2}' tyk-gateway.localhost:9002 addsvc.Add.Sum
