# Subscriptions
Spins up a GraphQL chat example application that can use WebSocket subscriptions.

## Setup

Run the `up.sh` script with the `subscriptions` parameter:

```
./up.sh subscriptions
```

### Environment variables

| Variable | Description | Required | Default |
| -------- | ----------- | -------- | ------- |
| SUBSCRIPTIONS_CHAT_APP_PORT | Sets the external port for the chat app | No | 8093 |

### Usage

This deployment will create a GraphQL proxy-only API to the chat example app from `graphql-go-tools`.

It is then accessible via `ws://tyk-gateway.localhost:8080/subscriptions-chat/`.

As exporting postman collection does not work for WebSocket requests ([feature request](https://github.com/postmanlabs/postman-app-support/issues/11252)), you can find example messages here:

#### graphql-ws
Set the header `Sec-WebSocket-Protocol` to `graphql-ws`.

##### Init
```json
{"type":"connection_init"}
```

##### Send query
```json
{"id":"1","type":"start","payload":{"query":"{ room(name:\"#my_room\") { name } }"}}
```

##### Send mutation
```json
{"id":"3","type":"start","payload":{"query":"mutation { post(text: \"hello\", username: \"me\", roomName: \"#my_room\") { text } }"}}
```

##### Start subscription
```json
{"id":"2","type":"start","payload":{"query":"subscription { messageAdded(roomName:\"#my_room\") { text } }"}}
```

##### Stop subscription
```json
{"id":"2","type":"stop"}
```

#### graphql-transport-ws
Set the header `Sec-WebSocket-Protocol` to `graphql-transport-ws`.

##### Init
```json
{"type":"connection_init"}
```

##### Send ping
```json
{"type":"ping","payload":"ping from client"}
```

##### Send query
```json
{"id":"1","type":"subscribe","payload":{"query":"{ room(name:\"#my_room\") { name } }"}}
```

##### Send mutation
```json
{"id":"3","type":"subscribe","payload":{"query":"mutation { post(text: \"hello\", username: \"me\", roomName: \"#my_room\") { text } }"}}
```

##### Start subscription
```json
{"id":"2","type":"subscribe","payload":{"query":"subscription { messageAdded(roomName:\"#my_room\") { text } }"}}
```

##### Stop subscription
```json
{"id":"2","type":"complete"}
```
