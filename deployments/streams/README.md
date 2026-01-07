# Kafka Master Data Streaming Example

## Overview
This directory contains scripts and examples for a master data streaming architecture using Kafka and Tyk Gateway. This example demonstrates a two-stage integration pattern:

1. **Stage 1: HTTP to Kafka** - Multiple producer systems post master data to HTTP endpoints, which are published to Kafka topics
2. **Stage 2: Kafka to HTTP** - Kafka messages are consumed by multiple downstream systems via two delivery patterns:
   - **SSE (Server-Sent Events)**: Real-time streaming for clients that can maintain persistent connections
   - **HTTP POST**: Push-based delivery for ERP systems that only accept HTTP POST requests
   
Both patterns support format transformation (JSON to XML) and data filtering capabilities.

## Quick Start (Docker Compose)

The easiest way to run the streams demo is using Docker Compose with the tyk-demo deployment system.

### Prerequisites

- Docker and Docker Compose installed
- tyk-demo repository cloned and set up
- Tyk Gateway and Tyk Dashboard running (started via `./up.sh` or docker-compose)

### Deployment Steps

1. **Start the Streams Demo:**
   ```bash
   # From the tyk-demo root directory
   ./up.sh streams
   ```

   This command will:
   - Import all API definitions into Tyk Gateway
   - Start the ERP servers container
   - Start the Web UI container
   - Connect all containers to the `tyk` network

2. **Access the Web UI:**
   Open your browser to: `http://localhost:8888`

3. **Start Demonstrating:**
   - Use the **Producer Form** to post master data items
   - Click **Start** on any of the SSE Consumer streams (JSON, XML, Filtered) to view real-time data
   - Click **Start** on the ERP Log viewers to see HTTP POST consumers delivering data to the ERP servers

That's it! The system is ready to use. All components are running and connected.

### What Gets Deployed

- **API Definitions**: 7 APIs automatically imported into Tyk Gateway
  - 1 Producer API (HTTP to Kafka)
  - 3 SSE Consumer APIs (JSON, XML, Filtered)
  - 3 HTTP POST Consumer APIs (JSON, XML, Filtered)
  
- **ERP Servers Container**: `erp-servers` running on ports 8001, 8002, 8003
- **Web UI Container**: `web-ui` running on port 8888

All containers are connected to the `tyk` network for proper communication.

### Verifying the Deployment

Check that all containers are running:
```bash
docker ps | grep -E "erp-servers|web-ui"
```

View logs:
```bash
# ERP servers logs
docker logs erp-servers

# Web UI logs  
docker logs web-ui
```

---

## Manual Deployment

If you prefer to run components manually (outside of Docker Compose), follow these steps:

### Prerequisites

- Kafka and Zookeeper must be installed and running
- Tyk Gateway should be running locally at `http://tyk-gateway.localhost:8080`
- Tyk Dashboard should be accessible for importing API definitions
- Python 3.x for running the fake ERP servers and Web UI

### Step 1: Import API Definitions into Tyk Gateway

Before you can use the system, you need to import the API definitions into Tyk Gateway. This includes the Producer API and all Consumer APIs (both SSE and HTTP POST patterns).

**Quick command:**
```bash
# Copy all API definitions to Tyk Dashboard data directory
cp data/tyk-dashboard/apis/api-streams-master-data*.json ../../../../data/tyk-dashboard/1/apis/
```

For detailed instructions including Dashboard UI import method, see the **[Importing API Definitions into Tyk Gateway](#importing-api-definitions-into-tyk-gateway)** section below.

### Step 2: Start Fake ERP Servers

If you want to test HTTP POST consumers, you'll need to start the fake ERP servers. These servers simulate downstream ERP systems that receive HTTP POST requests from Tyk Streams.

**Quick command:**
```bash
./start_erp_servers.sh
```

The servers will listen on:
- **JSON ERP**: `http://localhost:8001/erp/json/receive`
- **XML ERP**: `http://localhost:8002/erp/xml/receive`
- **Filtered ERP**: `http://localhost:8003/erp/filtered/receive`

For detailed instructions including individual server startup, log viewing, and Docker networking notes, see the **[ERP Server Setup](#erp-server-setup)** section below.

### Step 3: Start Web UI Server (Optional but Recommended)

The Web UI provides a convenient dashboard for posting data, viewing SSE streams, and monitoring ERP logs all in one place.

**Quick command:**
```bash
./start_web_ui.sh
```

Then open your browser to: `http://localhost:8888`

For more information about the Web UI features, see the **[WEB_UI.md](./WEB_UI.md)** file.

---

**Once you've completed these steps, you're ready to:**
- Post master data using the Producer API (see **[Scripts](#scripts)** section)
- Connect to SSE consumer streams for real-time data (see the **[Consumer Scripts](#consumer-scripts)** section)
- Monitor HTTP POST consumers delivering data to ERP servers (check ERP server logs)

For complete workflow examples, see the **[Example Workflows](#example-workflows)** section.

## Quick Reference: SSE vs HTTP POST

| Feature | SSE (Server-Sent Events) | HTTP POST |
|---------|-------------------------|-----------|
| **Connection Type** | Persistent HTTP connection | One-time HTTP POST per message |
| **Use Case** | Real-time streaming, monitoring, dashboards | ERP systems, webhooks, services that only accept POST |
| **Client Action** | Client connects and maintains connection | No client needed - Tyk Streams pushes automatically |
| **Consumer Groups** | `json-consumers`, `xml-consumers`, `filtered-consumers` | `json-consumers-http`, `xml-consumers-http`, `filtered-consumers-http` |
| **Endpoints** | `/streams-master-data-json/stream`<br>`/streams-master-data-xml/stream`<br>`/streams-master-data-filtered/stream` | Automatically POSTs to ERP servers |
| **Testing** | Use `consume_json.sh`, `consume_xml.sh`, `consume_filtered.sh` | Use `start_erp_servers.sh` and check logs |
| **When to Use** | Web browsers, mobile apps, monitoring tools | Legacy ERP systems, webhook endpoints, REST APIs |

## Canonical JSON Format

The master data should follow this canonical format:

```json
{
  "itemId": "string",
  "name": "string",
  "category": "string",
  "price": number,
  "description": "string",
  "status": "string",
  "lastUpdated": "ISO8601 timestamp"
}
```

Example:
```json
{
  "itemId": "12345",
  "name": "Widget A",
  "category": "Electronics",
  "price": 29.99,
  "description": "A high-quality widget",
  "status": "active",
  "lastUpdated": "2024-01-15T10:30:00Z"
}
```

## Scripts

### Producer Scripts

#### 1. `post_data.sh`
Sends a single master data item in canonical JSON format to the producer endpoint.

**Usage:**
```bash
./post_data.sh '{"itemId":"12345","name":"Widget A","category":"Electronics","price":29.99}'
```

#### 2. `post_batch_data.sh`
Sends multiple master data items in a single batch request. Uses the same `/producer` endpoint - Tyk Streams can handle both single items and arrays.

**Usage:**
```bash
# First create a JSON file with an array of items
cat > batch_items.json << EOF
[
  {"itemId":"123","name":"Item A","category":"Electronics","price":29.99},
  {"itemId":"456","name":"Item B","category":"Accessories","price":19.99},
  {"itemId":"789","name":"Item C","category":"Electronics","price":49.99}
]
EOF

# Then post the batch (uses the same /producer endpoint)
./post_batch_data.sh batch_items.json
```

### Consumer Scripts

This example provides scripts for both SSE and HTTP POST consumption patterns:

#### SSE Consumer Scripts (Real-Time Streaming)

These scripts connect to SSE endpoints and display messages in real-time as they arrive from Kafka:

#### 3. `consume_json.sh`
Connects to the JSON SSE stream endpoint and displays messages in real-time. Uses the `json-consumers` consumer group.

**Usage:**
```bash
./consume_json.sh
```

This will connect to `http://tyk-gateway.localhost:8080/streams-master-data-json/stream` and display messages as they arrive.

#### 4. `consume_xml.sh`
Connects to the XML SSE stream endpoint. Tyk Streams transforms JSON to XML before streaming. Uses the `xml-consumers` consumer group.

**Usage:**
```bash
./consume_xml.sh
```

This will connect to `http://tyk-gateway.localhost:8080/streams-master-data-xml/stream` and display XML messages.

#### 5. `consume_filtered.sh`
Connects to the filtered SSE stream endpoint. Only receives messages matching the filter criteria (Electronics category). Uses the `filtered-consumers` consumer group.

**Usage:**
```bash
# Listen for all filtered messages
./consume_filtered.sh
```

This will connect to `http://tyk-gateway.localhost:8080/streams-master-data-filtered/stream` and display filtered messages.

#### HTTP POST Consumer Setup (Push-Based Delivery)

For production ERP systems that only accept HTTP POST requests, use the HTTP POST consumer APIs. Tyk Streams automatically pushes data to your ERP servers - no client connection needed.

**Note:** Make sure you've started the fake ERP servers first (see "Quick Start: Starting Fake ERP Servers" section above).



## Example Workflows

### Scenario 1: Single Item Production with SSE Consumption (Real-Time Streaming)

This scenario demonstrates real-time streaming using SSE endpoints:

1. **Start SSE consumers (in separate terminals):**
   ```bash
   # Terminal 1: JSON SSE consumer
   ./consume_json.sh

   # Terminal 2: XML SSE consumer  
   ./consume_xml.sh

   # Terminal 3: Filtered SSE consumer
   ./consume_filtered.sh
   ```

2. **Producer posts data:**
   ```bash
   ./post_data.sh '{"itemId":"12345","name":"Widget","category":"Electronics","price":29.99}'
   ```

3. **Message flow:**
   - Producer → Tyk Gateway (HTTP POST) → Kafka Topic
   - Kafka Topic → Tyk Streams → SSE Stream Endpoints
   - Clients receive messages in real-time via SSE connections

4. **What you'll see:**
   - JSON consumer terminal shows the JSON message
   - XML consumer terminal shows the XML-transformed message
   - Filtered consumer terminal shows only Electronics items

### Scenario 2: Batch Production with HTTP POST Consumption (Push-Based)

This scenario demonstrates push-based delivery to ERP systems using HTTP POST:

1. **Start ERP servers (receives HTTP POST requests):**
   ```bash
   ./start_erp_servers.sh
   ```

2. **Create and post batch:**
   ```bash
   cat > batch.json << EOF
   [
     {"itemId":"001","name":"Widget A","category":"Electronics","price":29.99},
     {"itemId":"002","name":"Widget B","category":"Accessories","price":19.99},
     {"itemId":"003","name":"Widget C","category":"Electronics","price":49.99}
   ]
   EOF
   
   ./post_batch_data.sh batch.json
   ```

3. **Message flow:**
   - Producer → Tyk Gateway (HTTP POST) → Kafka Topic
   - Kafka Topic → Tyk Streams (Consumer Groups) → HTTP POST to ERP Servers
   - Tyk Streams automatically pushes data to ERP servers

4. **What you'll see:**
   - Check ERP server logs:
     ```bash
     tail -f /tmp/erp_json.log      # All items in JSON format
     tail -f /tmp/erp_xml.log       # All items in XML format
     tail -f /tmp/erp_filtered.log  # Only Electronics items
     ```

### Scenario 3: Mixed Consumption (SSE + HTTP POST)

You can use both patterns simultaneously - they use different consumer groups:

1. **Start both SSE consumers and ERP servers:**
   ```bash
   # Terminal 1-3: SSE consumers for real-time monitoring
   ./consume_json.sh
   ./consume_xml.sh
   ./consume_filtered.sh
   
   # Terminal 4: Start ERP servers for HTTP POST delivery
   ./start_erp_servers.sh
   ```

2. **Post data:**
   ```bash
   ./post_data.sh '{"itemId":"12345","name":"Widget","category":"Electronics","price":29.99}'
   ```

3. **Both patterns receive the message:**
   - SSE consumers: Real-time display in terminals
   - HTTP POST: Data pushed to ERP servers automatically

**Key Points:**
- SSE and HTTP POST use different consumer groups, so both receive all messages
- Messages are consumed independently by each consumer group (at-least-once delivery)
- You can use both patterns simultaneously for different use cases

## Kafka Consumer Groups

This example uses separate Kafka consumer groups for each consumer type to ensure independent message processing and at-least-once delivery:

### SSE (Server-Sent Events) Consumer Groups
- `json-consumers`: Consumer group for JSON format SSE consumers
- `xml-consumers`: Consumer group for XML format SSE consumers  
- `filtered-consumers`: Consumer group for filtered SSE consumers

### HTTP POST Consumer Groups
- `json-consumers-http`: Consumer group for JSON format HTTP POST consumers
- `xml-consumers-http`: Consumer group for XML format HTTP POST consumers
- `filtered-consumers-http`: Consumer group for filtered HTTP POST consumers

**Important Notes:**
- Each consumer group processes messages independently
- Messages are delivered to all consumer groups (at-least-once delivery)
- SSE and HTTP POST consumers use different groups, so both receive all messages
- Multiple instances of the same consumer type can process messages in parallel within the same consumer group

**Critical for SSE Streams: Consumer Group Offsets**
- Kafka consumer groups track message offsets, which means:
  - ✅ Messages posted **AFTER** you connect the stream will be received
  - ❌ Messages posted **BEFORE** you connect the stream will **NOT** be received (they were already consumed/processed)
- **Correct usage pattern**: Connect the SSE stream FIRST, then post new data
- If you don't see messages, try disconnecting and reconnecting the stream, then posting fresh data

## Tyk Streams Configuration Notes

The Tyk Gateway and Tyk Streams must be configured to:

1. **Producer Configuration**:
   - Accept POST requests at `/streams-master-data/producer`
   - Handles both single items (JSON object) and batch items (JSON array)
   - Publishes to Kafka topic: `master-data-items`

2. **Consumer Configurations - SSE (Server-Sent Events)**:
   - **JSON SSE Consumer**: 
     - Consume from Kafka topic
     - Use consumer group: `json-consumers`
     - Expose SSE endpoint: `/streams-master-data-json/stream`
     - Deliver original JSON format via SSE
   
   - **XML SSE Consumer**:
     - Consume from Kafka topic
     - Use consumer group: `xml-consumers`
     - Expose SSE endpoint: `/streams-master-data-xml/stream`
     - Transform JSON to XML using bloblang: `root = this.format_xml()`
     - Deliver XML format via SSE
   
   - **Filtered SSE Consumer**:
     - Consume from Kafka topic
     - Use consumer group: `filtered-consumers`
     - Expose SSE endpoint: `/streams-master-data-filtered/stream`
     - Apply filtering logic: `root = if this.category.lowercase() == "electronics" { this } else { deleted() }`
     - Deliver filtered data via SSE

3. **Consumer Configurations - HTTP POST (Push-Based)**:
   - **JSON HTTP POST Consumer**: 
     - Consume from Kafka topic
     - Use consumer group: `json-consumers-http`
     - Automatically send HTTP POST to: `http://host.docker.internal:8001/erp/json/receive`
     - Deliver original JSON format via HTTP POST
   
   - **XML HTTP POST Consumer**:
     - Consume from Kafka topic
     - Use consumer group: `xml-consumers-http`
     - Automatically send HTTP POST to: `http://host.docker.internal:8002/erp/xml/receive`
     - Transform JSON to XML using bloblang: `root = this.format_xml()`
     - Deliver XML format via HTTP POST
   
   - **Filtered HTTP POST Consumer**:
     - Consume from Kafka topic
     - Use consumer group: `filtered-consumers-http`
     - Automatically send HTTP POST to: `http://host.docker.internal:8003/erp/filtered/receive`
     - Apply filtering logic: `root = if this.category.lowercase() == "electronics" { this } else { deleted() }`
     - Deliver filtered data via HTTP POST

4. **At-Least-Once Delivery**:
   - Configure appropriate acknowledgment settings (`checkpoint_limit: 1`)
   - Use separate consumer groups to ensure each consumer type receives messages independently
   - SSE and HTTP POST consumers use different groups, so both receive all messages
   - Implement retry logic for failed HTTP POST requests to ERP systems

## ERP Server Setup

This example includes fake ERP servers (`fake_erp_servers.py`) that simulate downstream systems receiving HTTP POST requests from Tyk Streams consumers.

**Note:** For quick start instructions, see the "Quick Start: Starting Fake ERP Servers" section near the beginning of this README.

**Important:** Always use the `-u` flag (unbuffered output) when starting servers to ensure real-time log visibility.

### Stopping ERP Servers

```bash
./stop_erp_servers.sh
```

Or manually:
```bash
pkill -f "fake_erp_servers.py"
```

### Monitoring ERP Server Logs

The ERP servers write logs to:
- JSON ERP: `/tmp/erp_json.log`
- XML ERP: `/tmp/erp_xml.log`
- Filtered ERP: `/tmp/erp_filtered.log`

Monitor logs in real-time:
```bash
tail -f /tmp/erp_json.log
tail -f /tmp/erp_xml.log
tail -f /tmp/erp_filtered.log
```

### ERP Server Endpoints

- **JSON ERP**: `http://localhost:8001/erp/json/receive`
- **XML ERP**: `http://localhost:8002/erp/xml/receive`
- **Filtered ERP**: `http://localhost:8003/erp/filtered/receive`

**Note for Docker deployments:** If Tyk Gateway is running in Docker, update the consumer API configurations to use `host.docker.internal` instead of `localhost`:
- `http://host.docker.internal:8001/erp/json/receive`
- `http://host.docker.internal:8002/erp/xml/receive`
- `http://host.docker.internal:8003/erp/filtered/receive`

## Data Format Handling

### Single Items vs Batches

Tyk Streams can send data in two formats:
1. **Single item**: A JSON object `{"itemId": "...", "name": "..."}`
2. **Batch array**: A JSON array `[{"itemId": "..."}, {"itemId": "..."}]`

The ERP servers (`fake_erp_servers.py`) are configured to handle both formats automatically. They will:
- Detect if incoming data is a single object or an array
- Process each item individually
- Return appropriate responses with item counts

### Example Responses

**Single item response:**
```json
{
  "status": "received",
  "message": "Master data received successfully",
  "count": 1,
  "items": {"itemId": "12345"},
  "timestamp": "2025-11-19 14:47:00"
}
```

**Batch response:**
```json
{
  "status": "received",
  "message": "Master data received successfully",
  "count": 3,
  "items": [
    {"itemId": "12345"},
    {"itemId": "67890"},
    {"itemId": "11111"}
  ],
  "timestamp": "2025-11-19 14:47:00"
}
```

