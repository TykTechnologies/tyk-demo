# SSE Demo Scripts

## Overview
This directory contains scripts to demonstrate WebSocket communication with a Tyk gateway. These scripts help you test WebSocket connections by sending and receiving messages.

## Prerequisites
- Ensure you have `wscat` installed on your system.
- Tyk Demo is deployed, with the running locally at `http://tyk-gateway.localhost:8080`.

## Scripts

### 1. `listen_ws.sh`
This script listens to the WS endpoint at `ws://tyk-gateway.localhost:8080/streams-ws/get/ws`.

#### Usage:
```bash
./listen_ws.sh
```

When you run this script, it will continuously listen for incoming messages from the SSE stream and print them to the console.

### 2. `post_data.sh`
This script sends data to the `http://tyk-gateway.localhost:8080/streams-ws/post` endpoint.

#### Usage:
```bash
./post_data.sh "Your message here"

# Example:
./post_data.sh "Hello, WS!"
```