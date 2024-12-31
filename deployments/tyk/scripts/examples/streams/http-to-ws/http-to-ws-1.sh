#!/bin/bash

source scripts/common.sh

check_for_wscat

cat <<EOF
$(printf "\033[1mStreams - HTTP to Websocket Example\033[0m")

Part 1: Listening to a Websocket

Once connected, run part two of this example in a different terminal. The messages sent will appear here.

Connecting to the websocket...

EOF

wscat -c ws://tyk-gateway.localhost:8080/streams-http-to-websocket/subscribe
