# Loading API Definitions into Tyk Gateway

## Quick Start

All API definitions have been copied to the Tyk Dashboard data directory. You now need to reload Tyk Gateway for them to take effect.

### Step 1: Copy API Definitions (Already Done)

```bash
./load_apis.sh
```

This copies all 7 API definition files to the Tyk Dashboard data directory:
- `api-streams-master-data.json` (Producer)
- `api-streams-master-data-consumer-json.json` (JSON Consumer - SSE)
- `api-streams-master-data-consumer-xml.json` (XML Consumer - SSE)
- `api-streams-master-data-consumer-filtered.json` (Filtered Consumer - SSE)
- `api-streams-master-data-consumer-json-http.json` (JSON Consumer - HTTP POST)
- `api-streams-master-data-consumer-xml-http.json` (XML Consumer - HTTP POST)
- `api-streams-master-data-consumer-filtered-http.json` (Filtered Consumer - HTTP POST)

### Step 2: Reload Tyk Gateway

Choose one of these methods:

#### Option 1: Restart Tyk Gateway (Recommended)

**If running in Docker:**
```bash
docker restart <tyk-gateway-container-name>
```

**If running as a service:**
```bash
sudo systemctl restart tyk-gateway
```

**If running locally:**
```bash
# Stop and restart the Tyk Gateway process
```

#### Option 2: Reload via Dashboard UI

1. Log into Tyk Dashboard
2. Navigate to "APIs"
3. For each API (if they appear in the list):
   - Click on the API
   - Click "Save" (this triggers a reload)

**Note:** If the APIs don't appear in Dashboard, they may need to be imported first via Dashboard UI.

#### Option 3: Hot Reload via API (if supported)

```bash
curl -X GET http://tyk-gateway.localhost:8080/tyk/reload/group
```

### Step 3: Verify APIs Are Loaded

```bash
./verify_apis_loaded.sh
```

This script checks:
- ✓ Tyk Gateway is reachable
- ✓ Producer API endpoint
- ✓ Consumer API endpoints (SSE)
- ✓ API definition files in data directory

### Step 4: Test Individual Endpoints

```bash
# Test Producer
./post_data.sh '{"itemId":"TEST","name":"Test Item","category":"Electronics","price":29.99}'

# Test Consumer (SSE)
./consume_json.sh

# Verify endpoints
./verify_consumer.sh
```

## Troubleshooting

### APIs Still Not Loading

1. **Check File Location:**
   ```bash
   ls -la ../../../../data/tyk-dashboard/1/apis/api-streams-master-data*.json
   ```
   All 7 files should be present.

2. **Check File Format:**
   ```bash
   # Verify JSON files are valid
   for file in api-streams-master-data*.json; do
     echo "Checking $file..."
     python3 -m json.tool "$file" > /dev/null && echo "✓ Valid" || echo "✗ Invalid JSON"
   done
   ```

3. **Check Tyk Gateway Logs:**
   - Look for errors related to API loading
   - Check for JSON parsing errors
   - Verify API definitions are being read

4. **Check API Definition Format:**
   - Tyk Dashboard expects OpenAPI format with `x-tyk-api-gateway` extension
   - Verify the files have the correct structure

5. **Import via Dashboard UI (Alternative):**
   If direct file copy doesn't work, import via Dashboard:
   - Go to Dashboard → APIs → Add New API
   - Select "Import OpenAPI/AsyncAPI Definition"
   - Upload each JSON file

### API Endpoints Return 404

If endpoints return 404 after reload:
- Verify the `listenPath` in API definitions matches the endpoint
- Check that APIs are marked as "active" in the definitions
- Verify Tyk Gateway has reloaded (check logs)
- Try restarting Tyk Gateway completely

### Permission Issues

If you get permission errors:
```bash
# Check file permissions
ls -la ../../../../data/tyk-dashboard/1/apis/api-streams-master-data*.json

# Fix permissions if needed
chmod 644 ../../../../data/tyk-dashboard/1/apis/api-streams-master-data*.json
```

## API Files Location

- **Source:** `./api-streams-master-data*.json` (in kafka-master-data directory)
- **Destination:** `../../../../data/tyk-dashboard/1/apis/`
- **Full Path:** `/Users/lheritage/tykdemo/tyk-demo/deployments/tyk/data/tyk-dashboard/1/apis/`

## Scripts Available

- **`load_apis.sh`** - Copy API definitions to data directory
- **`verify_apis_loaded.sh`** - Verify APIs are loaded in gateway
- **`verify_consumer.sh`** - Test consumer endpoints
- **`post_data.sh`** - Test producer endpoint

