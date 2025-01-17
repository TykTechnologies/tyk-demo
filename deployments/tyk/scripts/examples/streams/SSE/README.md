# SSE Demo Scripts

## Overview
This directory contains two shell scripts designed to demonstrate HTTP streaming using Server-Sent Events (SSE) with a Tyk gateway. The first script posts data to an SSE endpoint, and the second script listens to the SSE stream.

## Prerequisites
- Ensure you have `curl` installed on your system.
- Tyk Demo is deployed, with the running locally at `http://tyk-gateway.localhost:8080`.

## Scripts

### 1. `listen_sse.sh`
This script listens to the SSE stream from the `http://tyk-gateway.localhost:8080/simple-stream/get/stream` endpoint.

#### Usage:
```bash
./listen_sse.sh
```

When you run this script, it will continuously listen for incoming messages from the SSE stream and print them to the console.

### 2. `post_data.sh`
This script sends data to the `http://tyk-gateway.localhost:8080/simple-stream/post` endpoint.

#### Usage:
```bash
./post_data.sh "Your message here"

# Example:
./post_data.sh "Hello, SSE!"
```