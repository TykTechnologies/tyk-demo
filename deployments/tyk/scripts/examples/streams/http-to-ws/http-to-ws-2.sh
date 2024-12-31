cat <<EOF
$(printf "\033[1mStreams - HTTP to Websocket Example\033[0m")

Part 2: Sending a message

Each time this script is run, the message \"Hello, Tyk Streams!\" will be received through the websocket in part 1. Check the other terminal to see the messages.

EOF

curl -d '{"message":"Hello, Tyk Streams!"}' http://tyk-gateway.localhost:8080/streams-http-to-websocket/post
