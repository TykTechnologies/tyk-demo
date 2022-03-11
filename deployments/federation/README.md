# Federation

Forked from https://github.com/zalbiraw/go-api-test-service

Runs 3 GraphQL Sub-Graph compliant services, and adds the Tyk APIs
- users, localhost:4001
- posts, localhost:4002
- comments, localhost:4003

## Setup

Run the `up.sh` script with the `federation` parameter:

```
./up.sh federation
```

## Usage

1. Once running, visit the Supergraph playground:

http://tyk-gateway.localhost:8080/social-media-apis-federated/playground

2. The example includes Users and Posts subgraph.  

3. Add the "comments" subgraph by adding a new Tyk API Subgraph:
```
http://comments-subgraph:4003/query
```

4. Add the subgraph to the "Social Media Federated Subgraph"