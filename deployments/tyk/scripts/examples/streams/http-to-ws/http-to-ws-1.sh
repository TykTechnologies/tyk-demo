echo "Streams - HTTP to Websocket Example"
echo "Part 1: Listening to a Websocket"
echo "Once connected, run part two of this example in a different terminal. The messages sent will appear here."
echo "Connecting to the websocket..."
wscat -c ws://tyk-gateway.localhost:8080/streams-http-to-websocket/subscribe
