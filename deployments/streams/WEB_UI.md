# Web UI Quick Reference

## Overview

The Web UI provides a beautiful, modern dashboard for interacting with the Kafka Master Data Streaming system. It combines producer posting, SSE consumer viewing, and ERP log monitoring in a single interface.

## Accessing the Web UI

### Docker Compose Deployment

If you deployed using `./up.sh streams`, the Web UI is already running and accessible at:

**http://localhost:8888**

Simply open this URL in your browser to access the dashboard.

### Manual Deployment

If running manually, start the Web UI server:

```bash
./start_web_ui.sh
```

The server will start on `http://localhost:8888`

**Dependencies:**
- Python 3.x
- Flask and Flask-CORS (automatically installed if missing)

### Docker Container

If running in a Docker container:

```bash
# Check if container is running
docker ps | grep web-ui

# View logs
docker logs web-ui

# Access at http://localhost:8888
```

## Features

### 1. Producer Form
- Fill out the form with master data fields (Item ID, Name, Category, Price, etc.)
- Click "Post to Producer" to send data to Kafka via Tyk Gateway
- Click "Show JSON" to preview the JSON payload before posting
- Real-time status feedback

### 2. SSE Consumer Streams
Three real-time streaming panels:
- **JSON Consumer**: Displays canonical JSON format
- **XML Consumer**: Displays JSON-to-XML transformed format  
- **Filtered Consumer**: Displays only Electronics category items

**Usage:**
- Click "Start" to begin streaming
- Messages appear in real-time as they arrive from Kafka
- Click "Stop" to disconnect

**Important:** Connect the streams first, then post data. Kafka consumer groups track offsets, so messages posted before connecting won't appear.

### 3. ERP Server Log Tails
Three log viewing panels that show real-time tails of ERP server logs:
- **JSON ERP Log**: `/tmp/erp_json.log`
- **XML ERP Log**: `/tmp/erp_xml.log`
- **Filtered ERP Log**: `/tmp/erp_filtered.log`

**Usage:**
- Click "Start" to begin tailing logs
- Logs auto-refresh every second
- Click "Clear" to reset the log view
- Click "Stop" to stop tailing

**Note:** 
- With Docker Compose: Logs are automatically available via shared volume
- Manual deployment: ERP servers must be running (`./start_erp_servers.sh`) for logs to appear

## Architecture

### Frontend
- **HTML**: `web_ui/index.html` - Main UI structure
- **CSS**: `web_ui/styles.css` - Modern, responsive styling
- **JavaScript**: `web_ui/app.js` - Client-side logic

### Backend
- **Python Flask Server**: `web_ui_server.py`
  - Serves static files (HTML/CSS/JS)
  - Provides REST API for log tailing
  - Proxies SSE streams from Tyk Gateway
  - Handles log file reading with position tracking

## API Endpoints

The web UI server provides these endpoints:

- `GET /` - Main UI page
- `POST /api/producer` - Proxy for posting data to Tyk Gateway producer endpoint
- `GET /api/stream/<type>` - Proxy SSE stream (json/xml/filtered)
- `GET /api/logs/<type>` - Get tail of log file (json/xml/filtered)
- `GET /api/logs/<type>/reset` - Reset log position and clear log file
- `GET /api/health` - Health check with log file status

## Configuration

### Environment Variables

- `TYK_GATEWAY_URL`: Tyk Gateway URL (default: `http://tyk-gateway.localhost:8080`)
  - For Docker: Use `http://tyk-gateway:8080` (Docker service name)
  - For manual: Use `http://tyk-gateway.localhost:8080` or `http://localhost:8080`

### Frontend Configuration

All frontend configuration is in `web_ui/app.js`:

- **Producer URL**: Proxied through `/api/producer`
- **SSE URLs**: Proxied through `/api/stream/<type>` (avoids CORS issues)
- **Log Poll Interval**: 1000ms (1 second)

## Troubleshooting

### SSE Consumers Not Connecting
- Verify Tyk Gateway is running and accessible
- Check that consumer APIs are loaded in Tyk Dashboard
- For Docker: Verify `TYK_GATEWAY_URL` environment variable is set correctly
- Check browser console (F12) for connection errors

### Log Files Not Showing
- **Docker Compose**: Verify `erp-logs` volume is shared between containers
- **Manual**: Ensure ERP servers are running: `./start_erp_servers.sh`
- Check log files exist: `ls -lh /tmp/erp_*.log`
- Verify log file paths in `web_ui_server.py`

### Producer Posts Failing
- Verify Tyk Gateway is accessible at configured URL
- Check producer API is loaded in Tyk Dashboard
- Review browser console for CORS or network errors
- Check web-ui container logs: `docker logs web-ui`

### Port Already in Use
If port 8888 is already in use:

**Docker Compose:** Update `docker-compose.yml`:
```yaml
ports:
  - "8889:8888"  # Change host port
```

**Manual:** Modify `web_ui_server.py`:
```python
app.run(host='0.0.0.0', port=8889, ...)  # Change port number
```

## File Structure

```
streams/
├── web_ui/
│   ├── index.html      # Main UI page
│   ├── styles.css      # Styling
│   └── app.js          # Client-side JavaScript
├── web_ui_server.py    # Flask backend server
├── Dockerfile.webui    # Docker image definition
├── requirements-webui.txt  # Python dependencies
└── start_web_ui.sh     # Manual startup script
```