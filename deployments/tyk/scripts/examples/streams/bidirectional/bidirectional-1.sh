#!/bin/bash

source scripts/common.sh

check_for_wscat

cat <<EOF
$(printf "\033[1mStreams - Bidirectional\033[0m")

Part 1: Listen for events based for 'dev1'

This example uses kafka and Tyk context data to dynamically deliver messages based on the input.
This part connects to a websocket as user 'dev1' and waits to receive messages for the user.

Now run part 2 in a different terminal, to connect as 'dev2'.

EOF

wscat -c http://localhost:8080/streams-bidirectional/ws\?user\=dev1
