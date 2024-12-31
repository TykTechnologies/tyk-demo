cat <<EOF
$(printf "\033[1mStreams - Bidirectional\033[0m")

Part 4: Send a message to 'dev2'

Same as part 3, but message is sent to 'dev2'

Now check the first and second terminals, only the second terminal ('dev2') will have received the message.

EOF

curl -X POST http://localhost:8080/streams-bidirectional/event\?user\=dev2 -d '{"Tyk": "Streams"}'
