#!/bin/bash

source scripts/common.sh

check_for_wscat

echo "Streams - Bidirectional"
echo "Part 1: Listen for events based for 'dev1'"
echo "This example uses kafka and Tyk context data to dynamically deliver messages based on the input."
echo "This part connects to a websocket as user 'dev1' and waits to receive messages for the user."
echo "Now run part two in a different terminal, to connect as 'dev2'."
wscat -c http://localhost:8080/streams-bidirectional/ws\?user\=dev1
