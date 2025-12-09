# Kafka Master Data Streaming Example

## Overview
This directory contains scripts and examples for a master data streaming architecture using Kafka and Tyk Gateway. This example demonstrates a two-stage integration pattern:

1. **Stage 1: HTTP to Kafka** - Multiple producer systems post master data to HTTP endpoints, which are published to Kafka topics
2. **Stage 2: Kafka to HTTP** - Kafka messages are consumed by multiple downstream systems via two delivery patterns:
   - **SSE (Server-Sent Events)**: Real-time streaming for clients that can maintain persistent connections
   - **HTTP POST**: Push-based delivery for ERP systems that only accept HTTP POST requests
   
Both patterns support format transformation (JSON to XML) and data filtering capabilities.

## Quick Start

Follow these three steps to get the Kafka Master Data Streaming system up and running:

### Step 1: Import API Definitions into Tyk Gateway

Before you can use the system, you need to import the API definitions into Tyk Gateway. This includes the Producer API and all Consumer APIs (both SSE and HTTP POST patterns).

**Quick command:**
```bash
# Copy all API definitions to Tyk Dashboard data directory
cp api-streams-master-data*.json ../../../../data/tyk-dashboard/1/apis/
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

## Architecture Requirements

### Producer Side Requirements
- **Multiple Master Data Sources**: Multiple producer systems maintain master data for items in a canonical JSON format
- **HTTP Ingestion Endpoint**: POST endpoint to publish all updates from producer systems
- **Kafka Publishing**: Using Tyk Streams, the payload of (potentially batched) requests is published to a single Kafka topic
- **Canonical Format**: All data is published in a standardized JSON format

### Consumer Side Requirements
- **Multiple Downstream Consumers**: Multiple ERP business units and systems consume the master data
- **Two Delivery Patterns**:
  - **SSE (Server-Sent Events)**: For real-time streaming to clients that can maintain persistent HTTP connections
  - **HTTP POST**: For ERP systems that only accept HTTP POST requests (no WebSockets or Kafka connectivity)
- **Format Transformation**: Some consumers need canonical JSON format, others require XML conversion
- **Data Filtering**: Some consumers should only receive a filtered subset of data based on specific properties. In this example the filter is on the category property of the item.  You specify the filter in the Pipeline Processor in the api definition
- **At-Least-Once Delivery**: All systems require at least once delivery using separate Kafka consumer groups

### Integration Platform Requirements
- **Centralized Management**: Platform to manage the flow of master data between producers and consumers
- **Two-Stage Processing**:
  - Stage 1: HTTP to Kafka (for producers)
  - Stage 2: Kafka to HTTP (for consumers) - supports both SSE and HTTP POST patterns
- **Multiple Delivery Patterns**: 
  - SSE endpoints for real-time streaming
  - HTTP POST for push-based delivery to ERP systems
- **Transformation Capabilities**: Convert between formats (JSON to XML)
- **Filtering Logic**: Filter data based on properties. In this example it is the "category" property.
- **Multiple Output Targets**: Support for sending to multiple downstream systems with different requirements

## Prerequisites
- Kafka and Zookeeper must be installed and running
- Tyk Gateway should be running locally at `http://tyk-gateway.localhost:8080`
- Tyk Dashboard should be accessible for importing API definitions
- Tyk Streams must be configured with:
  - Producer endpoint: `/streams-master-data/producer` (handles both single items and batches)
  - **SSE Consumer endpoints** (for real-time streaming):
    - JSON: `/streams-master-data-json/stream`
    - XML: `/streams-master-data-xml/stream`
    - Filtered: `/streams-master-data-filtered/stream`
  - **HTTP POST Consumer endpoints** (for ERP systems):
    - JSON: Automatically POSTs to `http://host.docker.internal:8001/erp/json/receive`
    - XML: Automatically POSTs to `http://host.docker.internal:8002/erp/xml/receive`
    - Filtered: Automatically POSTs to `http://host.docker.internal:8003/erp/filtered/receive`
- Python 3.x for running the fake ERP servers (for HTTP POST consumer testing)

## Importing API Definitions into Tyk Gateway

This example includes Tyk API Gateway configuration files that can be imported into Tyk Dashboard. Since Tyk Streams requires separate API definitions for producer and each consumer type, multiple files are provided:

### API Definition Files

#### Producer API

1. **`api-streams-master-data.json`** - Producer API definition (HTTP to Kafka)
   - Accepts POST requests at `/streams-master-data/producer`
   - Handles both single items (JSON object) and batch items (JSON array)
   - Publishes to Kafka topic: `master-data-items`

#### Consumer APIs - Two Delivery Patterns

This example provides two delivery patterns for consuming Kafka messages:

**Pattern 1: SSE (Server-Sent Events) - Real-Time Streaming**

These consumers expose SSE endpoints that clients connect to for real-time streaming. Use this pattern when:
- Clients can maintain persistent HTTP connections
- Real-time updates are required
- You want to stream data as it arrives

2. **`api-streams-master-data-consumer-json.json`** - JSON Consumer API (SSE)
   - Consumer group: `json-consumers`
   - Stream path: `/streams-master-data-json/stream`
   - Delivers canonical JSON format via SSE
   - Clients connect via: `curl -N http://tyk-gateway.localhost:8080/streams-master-data-json/stream`

3. **`api-streams-master-data-consumer-xml.json`** - XML Consumer API (SSE)
   - Consumer group: `xml-consumers`
   - Stream path: `/streams-master-data-xml/stream`
   - Transforms JSON to XML before streaming
   - Clients connect via: `curl -N http://tyk-gateway.localhost:8080/streams-master-data-xml/stream`

4. **`api-streams-master-data-consumer-filtered.json`** - Filtered Consumer API (SSE)
   - Consumer group: `filtered-consumers`
   - Stream path: `/streams-master-data-filtered/stream`
   - Filters data (Electronics category only) before streaming
   - Clients connect via: `curl -N http://tyk-gateway.localhost:8080/streams-master-data-filtered/stream`

**Pattern 2: HTTP POST - Push-Based Delivery**

These consumers automatically send HTTP POST requests to downstream ERP systems. Use this pattern when:
- ERP systems only accept HTTP POST requests
- Systems cannot maintain persistent connections
- You need push-based delivery (Tyk Streams pushes to ERP)

5. **`api-streams-master-data-consumer-json-http.json`** - JSON Consumer API (HTTP POST)
   - Consumer group: `json-consumers-http`
   - Automatically sends HTTP POST requests to: `http://host.docker.internal:8001/erp/json/receive`
   - Delivers canonical JSON format via HTTP POST
   - No client connection needed - Tyk Streams pushes data automatically

6. **`api-streams-master-data-consumer-xml-http.json`** - XML Consumer API (HTTP POST)
   - Consumer group: `xml-consumers-http`
   - Automatically sends HTTP POST requests to: `http://host.docker.internal:8002/erp/xml/receive`
   - Transforms JSON to XML before sending
   - No client connection needed - Tyk Streams pushes data automatically

7. **`api-streams-master-data-consumer-filtered-http.json`** - Filtered Consumer API (HTTP POST)
   - Consumer group: `filtered-consumers-http`
   - Automatically sends HTTP POST requests to: `http://host.docker.internal:8003/erp/filtered/receive`
   - Filters data (Electronics category only) before sending
   - No client connection needed - Tyk Streams pushes data automatically

**Choosing Between SSE and HTTP POST:**
- **Use SSE** when you have clients that can connect and maintain persistent connections (web browsers, mobile apps, monitoring tools)
- **Use HTTP POST** when you have ERP systems or services that only accept HTTP POST requests and cannot maintain persistent connections

### How to Import

**Recommended Method 1: Via Tyk Dashboard UI (OpenAPI Format)**

These files are in OpenAPI format and work best when imported through the Dashboard UI:

1. Log in to Tyk Dashboard
2. For each API definition file:
   - Navigate to "APIs" → "Add New API"
   - Select "Import OpenAPI/AsyncAPI Definition"
   - Upload or paste the contents of the JSON file
   - Configure any additional settings (transformations, filters) in the UI
   - Save the API

**Recommended Method 2: Copy to Dashboard Data Directory**

This method works if you have direct access to the Tyk Dashboard data directory:

```bash
# From the kafka-master-data directory
cd /Users/lheritage/tykdemo/tyk-demo/deployments/tyk/scripts/examples/streams/kafka-master-data

# Copy all API definitions to your Tyk Dashboard data directory
# Adjust the path based on your deployment structure
cp api-streams-master-data*.json ../../../../data/tyk-dashboard/1/apis/

# Restart Tyk Dashboard to load the APIs
# Or trigger a reload via the Gateway
```

**Note:** The `/api/apis` endpoint expects the full `api_definition` format, not OpenAPI. For OpenAPI format files, use the Dashboard UI import or copy directly to the data directory as shown above.

**Note:** After importing, you may need to configure:
- **XML Transformation**: Configure JSON to XML transformation middleware in the XML consumer API
- **Filtering Logic**: Configure filtering middleware in the filtered consumer API (e.g., filter by category property)
- **Downstream URLs**: Update the `http_server` output URLs in consumer APIs to point to your actual ERP system endpoints

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

#### Testing HTTP POST Consumers
```bash
# Run comprehensive test
./test_http_consumers.sh

# Or diagnose issues
./diagnose_http_consumers.sh
```

The HTTP POST consumers automatically send data to the ERP servers when messages arrive in Kafka. No manual connection needed - Tyk Streams handles the HTTP POST requests automatically.


### Testing Scripts

#### 6. `test.sh`
Automated test script for SSE consumers that verifies the end-to-end flow:
- Posts test data to producer endpoint
- Verifies JSON SSE consumer receives messages
- Verifies XML SSE consumer receives transformed messages
- Verifies filtered SSE consumer receives filtered messages

**Usage:**
```bash
# Start SSE consumers first, then run test
./consume_json.sh &    # In separate terminals
./consume_xml.sh &
./consume_filtered.sh &
./test.sh
```

#### 7. `test_http_consumers.sh`
Automated test script for HTTP POST consumers that verifies push-based delivery:
- Checks ERP servers are running
- Posts test data to producer endpoint
- Verifies HTTP POST consumers push data to ERP servers
- Tests filtering (Electronics vs non-Electronics)

**Usage:**
```bash
# Start ERP servers first
./start_erp_servers.sh

# In another terminal, run test
./test_http_consumers.sh

# Check logs to verify receipt
tail -f /tmp/erp_json.log
tail -f /tmp/erp_filtered.log
```

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

## Troubleshooting

### Common Issues and Solutions

#### 1. Messages not appearing in consumers
- **Check**: Tyk Streams is properly configured and connected to Kafka
- **Verify**: Consumer APIs are loaded in Tyk Gateway
- **Test**: Use `./diagnose_http_consumers.sh` to check connectivity

#### 2. XML transformation not working
- **Check**: Transformation middleware is configured in Tyk Streams
- **Verify**: The XML consumer API has the bloblang processor configured
- **Example**: `root = this.format_xml()`

#### 3. Filtering not working
- **Check**: Filter configuration in Tyk Streams matches property names in canonical format
- **Verify**: The filtered consumer API has the bloblang filter configured
- **Example**: `root = if this.category.lowercase() == "electronics" { this } else { deleted() }`

#### 4. Consumer groups not working
- **Verify**: Each consumer endpoint uses a different consumer group in Tyk Streams configuration
- **Check**: Consumer groups are properly named (e.g., `json-consumers-http`, `xml-consumers-http`, `filtered-consumers-http`)

#### 5. AttributeError: 'list' object has no attribute 'get'
- **Cause**: ERP server received a batch array but code expected a single object
- **Solution**: The ERP servers have been updated to handle both formats. Restart servers with:
  ```bash
  ./stop_erp_servers.sh
  ./start_erp_servers.sh
  ```

#### 6. No output in log files
- **Cause**: Python output buffering prevents real-time log visibility
- **Solution**: 
  - Always use `-u` flag: `python3 -u fake_erp_servers.py filtered`
  - Or use the provided `start_erp_servers.sh` script which includes `-u`
  - The script has been updated with unbuffered output configuration

#### 7. ERP servers not receiving data from Tyk Gateway
- **Check**: ERP servers are running (`lsof -ti:8001,8002,8003`)
- **Verify**: Consumer API URLs are correct (use `host.docker.internal` if Tyk is in Docker)
- **Test**: Send direct test request: `curl -X POST http://localhost:8003/erp/filtered/receive -H "Content-Type: application/json" -d '{"test":"data"}'`
- **Check**: Tyk Gateway logs for consumer errors

#### 8. Consumer APIs showing 404
- **Cause**: APIs not loaded in Tyk Dashboard
- **Solution**: 
  ```bash
  # Copy API definitions to data directory
  cp api-streams-master-data*.json ../../../../data/tyk-dashboard/1/apis/
  # Restart Tyk Dashboard or trigger reload
  ```

#### 9. SSE Stream "Connection timeout" or no messages appearing
- **Cause**: SSE streams keep connections open waiting for data - "timeout" messages are often misleading
- **Check**: Connection is actually established (check browser DevTools Network tab for HTTP 200)
- **Solution**: 
  1. Connect the stream FIRST (click "Start" on consumer)
  2. THEN post new data using the Producer form
  3. Remember: Consumer groups track offsets - messages posted before connecting won't appear
- **Test direct connection** (bypass web UI proxy):
  ```bash
  # Terminal 1: Connect to stream
  ./consume_json.sh
  
  # Terminal 2: Post data while stream is connected
  ./post_data.sh '{"itemId":"TEST","name":"Test Item","category":"Electronics","price":29.99}'
  ```
- **Check web UI server logs**: `tail -f /tmp/web_ui_server.log`
- **Verify proxy endpoint**: `curl -N http://localhost:8888/api/stream/json` (will hang - that's normal, it's waiting for data)

#### 10. SSE Stream "ReadyState: 0" (CONNECTING)
- **Cause**: Connection isn't completing
- **Check**: Tyk Gateway is running: `curl http://tyk-gateway.localhost:8080/`
- **Check**: Web UI server logs for errors
- **Verify**: APIs are loaded: `./verify_apis_loaded.sh`

### Diagnostic Tools

#### `diagnose_http_consumers.sh`
Comprehensive diagnostic script that checks:
- ERP server status
- Direct connectivity to ERP servers
- Consumer API accessibility
- Kafka message availability
- End-to-end data flow

**Usage:**
```bash
./diagnose_http_consumers.sh
```

#### `test_http_consumers.sh`
Tests the complete flow: Producer → Kafka → Consumer → HTTP POST → ERP

**Usage:**
```bash
./test_http_consumers.sh
```

#### `check_kafka_messages.sh`
Verifies messages are in the Kafka topic

**Usage:**
```bash
./check_kafka_messages.sh
```

### Verifying End-to-End Flow

1. **Start ERP servers:**
   ```bash
   ./start_erp_servers.sh
   ```

2. **Post test data:**
   ```bash
   ./post_data.sh '{"itemId":"TEST-001","name":"Test Item","category":"Electronics","price":29.99}'
   ```

3. **Check logs:**
   ```bash
   tail -f /tmp/erp_json.log
   tail -f /tmp/erp_filtered.log
   ```

4. **Verify all consumers received data:**
   - JSON consumer should show the item
   - XML consumer should show XML format
   - Filtered consumer should show only Electronics items

### Gateway Logs

Check Tyk Gateway logs for consumer processing:
```bash
docker logs $(docker ps --format '{{.Names}}' | grep -i gateway | head -1) | grep -i stream
```

Or if running locally, check the gateway log file for Streams-related messages.

## Key Findings and Improvements

During implementation and testing, several important issues were identified and resolved:

### 1. Batch Data Handling
**Issue**: ERP servers initially expected only single JSON objects, but Tyk Streams can send both single items and batch arrays, causing `AttributeError: 'list' object has no attribute 'get'`.

**Solution**: Updated all three ERP handlers (JSON, XML, Filtered) to automatically detect and handle both formats:
- Single items: `{"itemId": "...", "name": "..."}`
- Batch arrays: `[{"itemId": "..."}, {"itemId": "..."}]`

The handlers now iterate through items and process each one individually, making the system robust to both data formats.

### 2. Log Visibility
**Issue**: Python's output buffering prevented real-time log visibility when servers were started in the background.

**Solution**: 
- Added unbuffered output configuration to `fake_erp_servers.py`
- Updated `start_erp_servers.sh` to use `python3 -u` flag (unbuffered mode)
- Logs now appear in real-time in `/tmp/erp_*.log` files

### 3. Consumer API Configuration
**Issue**: Consumer API definitions need to be in the Tyk Dashboard data directory for the gateway to load them.

**Solution**: Provided clear instructions and script to copy all consumer API definitions:
```bash
cp api-streams-master-data*.json ../../../../data/tyk-dashboard/1/apis/
```

### 4. Docker Networking
**Issue**: When Tyk Gateway runs in Docker, it cannot reach `localhost` on the host machine.

**Solution**: Consumer API configurations use `host.docker.internal` instead of `localhost` for HTTP client outputs, allowing Docker containers to reach host services.

### 5. Diagnostic Tools
**Enhancement**: Created comprehensive diagnostic scripts:
- `diagnose_http_consumers.sh` - Full system health check
- `test_http_consumers.sh` - End-to-end flow testing
- `check_kafka_messages.sh` - Kafka topic verification

These tools help quickly identify issues in the data flow pipeline.
