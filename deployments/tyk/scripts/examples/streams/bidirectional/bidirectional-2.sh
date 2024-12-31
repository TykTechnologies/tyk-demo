#!/bin/bash

source scripts/common.sh

check_for_wscat

cat <<EOF
$(printf "\033[1mStreams - Bidirectional\033[0m")

Part 2: Listen for events based for 'dev2'

Now run part 3 in a different terminal, to send a message to 'dev1'.

EOF

wscat -c http://localhost:8080/streams-bidirectional/ws\?user\=dev2
