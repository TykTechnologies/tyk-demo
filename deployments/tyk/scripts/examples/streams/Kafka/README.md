# Kafka Demo Scripts

## Overview
This directory contains scripts to demonstrate Kafka message streaming with a Tyk gateway. These scripts help you test Kafka message production and consumption using different methods.

## Prerequisites
- Ensure you have Kafka and Zookeeper installed and running on your system.
- The Tyk Gateway should be running locally at `http://tyk-gateway.localhost:8080`.

## Scripts

### 1. `post_data.sh`
This script sends a message to a Kafka topic via a POST request.

#### Usage:
```bash
./post_data.sh "Your message here"

# Example:
./post_data.sh "Hello, Kafka!"
```

### 2. `listen_sse.sh`
This script listens to messages from a Kafka topic using Server-Sent Events (SSE) through the Tyk gateway.

#### Usage:
```bash
./listen_sse.sh
```

### 3. `listen_cli.sh`
A bonus script that shows the direct consumption of messages from Kafka, using Kafka's own console consumer script, and without going through the Tyk gateway.

#### Usage:
```bash
./listen_cli.sh
```
