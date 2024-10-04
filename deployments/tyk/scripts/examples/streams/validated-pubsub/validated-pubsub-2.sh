echo "Streams - Validated PubSub"
echo "Part 2: Publishing a valid message"
echo "This script publishes a valid message to the clients connected in script 1."
echo "Check the first terminal to see the messages received."

curl http://tyk-gateway.localhost:8080/streams-simple-pubsub/validated-pub -d '{ "name": "Tyk Streams", "age": 1 }'
