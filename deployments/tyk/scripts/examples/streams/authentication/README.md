# Authentication Demo Scripts for Streaming APIs

## Overview
This directory contains scripts to demonstrate how authentication can be added to streaming APIs with a Tyk gateway. These scripts help you test authenticated and unauthenticated message production and consumption using Server-Sent Events (SSE).

The authentication token is already embedded into the scripts.

## Prerequisites
- Ensure you have `curl` installed on your system.
- Tyk Demo is deployed, with the gateway running locally at `http://tyk-gateway.localhost:8080`.

## Scripts

### 1. `listen.sh`
This script listens to messages from a streaming API endpoint using Server-Sent Events (SSE) with authentication.

#### Usage:
```bash
./listen.sh
```

### 2. `post_data_unauth.sh`
This script attempts to send a pre-defined message to a streaming API endpoint without authentication. The authenticated request will fail, and therefore nothing will be received by the listening script.

#### Usage:
```bash
./post_data_unauth.sh
```

### 3. `post_data_auth.sh`
This script sends a message to a streaming API endpoint with authentication. The listening script will receive the message.

#### Usage:
```bash
./post_data_auth.sh "Your message here"

# Example:
./post_data_auth.sh "Hello, authenticated!"
```

When you run these scripts, you can see how the Tyk gateway handles authentication for streaming APIs.