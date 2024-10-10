#!/bin/bash

source scripts/common.sh

check_for_wscat

echo "Streams - Bidirectional"
echo "Part 2: Listen for events based for 'dev2'"
echo "Now run part three in a different terminal, to send a message to 'dev1'."
wscat -c http://localhost:8080/streams-bidirectional/ws\?user\=dev2
