echo "Streams - Bidirectional"
echo "Part 3: Send a message to 'dev1'"
echo "This part posts data to the stream via Tyk. The data is processed and delivered to the user defined in the querystring."
echo "Check terminals one and two, only the first terminal ('dev1') will have received the message."
curl -X POST http://localhost:8080/streams-bidirectional/event\?user\=dev1 -d '{"foo": "bar"}'
