cat <<EOF
$(printf "\033[1mStreams - HTTP to AMQP\033[0m")

Part 2: Send a message

Each time this script is run, the message 'Hello, Tyk Streams!' is sent via the message broker, RabbitMQ.
Tyk converts the HTTP POST request into an AMQP publish message, which is then placed in the RabbitMQ message queue.

Now check the first terminal to see that the message is received.

EOF

curl -X POST http://tyk-gateway.localhost:8080/streams-http-to-amqp/post -d '{"message": "Hello, Tyk Streams!"}' -H "Content-Type: application/json"