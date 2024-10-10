echo "Streams - Bidirectional"
echo "Part 4: Send a message to 'dev2'"
echo "Same as part 3, but message is sent to 'dev2'"
echo "Check terminals one and two, only the second terminal ('dev2') will have received the message."
curl -X POST http://localhost:8080/streams-bidirectional/event\?user\=dev2 -d '{"Tyk": "Streams"}'
