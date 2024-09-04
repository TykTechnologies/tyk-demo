#wip

echo "Sending gRPC request via tls-multiplex-1.localhost"
grpcurl -insecure -d '{"greeting":"Maus"}' tls-multiplex-1.localhost:9005 hello.HelloService.SayHello
echo "Sending gRPC request via tls-multiplex-2.localhost"
grpcurl -insecure -d '{"greeting":"Ralph"}' tls-multiplex-2.localhost:9005 hello.HelloService.SayHello