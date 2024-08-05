#!/bin/bash

echo "Streams - HTTP to Websocket Example"
echo "Part 2: Sending a message"
echo "Each time this script is run, the message \"Hello, Tyk Streams!\" will be received through the websocket in part 1. Check the other terminal to see the messages."
curl -d '{"message":"Hello, Tyk Streams!"}' http://tyk-gateway.localhost:8080/streams-http-to-websocket/post
