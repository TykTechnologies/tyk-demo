cat <<EOF
$(printf "\033[1mStreams - Bidirectional\033[0m")

Part 3: Send a message to 'dev1'

This part posts data to the stream via Tyk. The data is processed and delivered to the user defined in the querystring.

Now check the first and second terminals, only the first terminal ('dev1') will have received the message.

EOF

curl -X POST http://localhost:8080/streams-bidirectional/event\?user\=dev1 -d '{"foo": "bar"}'
