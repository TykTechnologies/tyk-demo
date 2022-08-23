# Federation

Forked from https://github.com/zalbiraw/go-api-test-service

Runs 3 GraphQL Sub-Graph compliant services, and adds the Tyk APIs
- users, localhost:4201
- posts, localhost:4202
- comments, localhost:4203
- notifications, localhost:4204

## Setup

Run the `up.sh` script with the `federation` parameter:

```
./up.sh federation
```

## Usage

1. Once running, visit the Supergraph playground:

http://tyk-gateway.localhost:8080/social-media-federated-graph/playground

2. The example includes Users and Posts subgraph.  

3. Add the "comments-subgraph" subgraph by adding a new Tyk API Subgraph:
```
http://comments-subgraph:4203/query
```

4. Add the subgraph to the "Social Media Federated Subgraph"
