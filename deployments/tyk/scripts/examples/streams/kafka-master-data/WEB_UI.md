# Web UI Quick Reference

## Overview

The Web UI provides a beautiful, modern dashboard for interacting with the Kafka Master Data Streaming system. It combines producer posting, SSE consumer viewing, and ERP log monitoring in a single interface.

## Starting the Web UI

```bash
./start_web_ui.sh
```

The server will start on `http://localhost:8888`

**Dependencies:**
- Python 3.x
- Flask and Flask-CORS (automatically installed if missing)

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

**Note:** ERP servers must be running (`./start_erp_servers.sh`) for logs to appear.

## Architecture

### Frontend
- **HTML**: `web_ui/index.html` - Main UI structure
- **CSS**: `web_ui/styles.css` - Modern, responsive styling
- **JavaScript**: `web_ui/app.js` - Client-side logic

### Backend
- **Python Flask Server**: `web_ui_server.py`
  - Serves static files (HTML/CSS/JS)
  - Provides REST API for log tailing
  - Handles log file reading with position tracking

## API Endpoints

The web UI server provides these endpoints:

- `GET /` - Main UI page
- `GET /api/logs/<type>` - Get tail of log file (json/xml/filtered)
- `GET /api/logs/<type>/reset` - Reset log position
- `GET /api/health` - Health check with log file status

## Configuration

All configuration is in `web_ui/app.js`:

- **Producer URL**: `http://tyk-gateway.localhost:8080/streams-master-data/producer`
- **SSE URLs**: 
  - JSON: `http://tyk-gateway.localhost:8080/streams-master-data-json/stream`
  - XML: `http://tyk-gateway.localhost:8080/streams-master-data-xml/stream`
  - Filtered: `http://tyk-gateway.localhost:8080/streams-master-data-filtered/stream`
- **Log Poll Interval**: 1000ms (1 second)

## Troubleshooting

### SSE Consumers Not Connecting
- Verify Tyk Gateway is running and accessible
- Check that consumer APIs are loaded in Tyk Dashboard
- Verify endpoints are correct in `app.js`

### Log Files Not Showing
- Ensure ERP servers are running: `./start_erp_servers.sh`
- Check log files exist: `ls -lh /tmp/erp_*.log`
- Verify log file paths in `web_ui_server.py`

### Producer Posts Failing
- Verify Tyk Gateway is accessible at configured URL
- Check producer API is loaded in Tyk Dashboard
- Review browser console for CORS or network errors

### Port Already in Use
If port 8888 is already in use, modify `web_ui_server.py`:
```python
app.run(host='0.0.0.0', port=8888, ...)  # Change port number
```

## File Structure

```
kafka-master-data/
├── web_ui/
│   ├── index.html      # Main UI page
│   ├── styles.css      # Styling
│   └── app.js          # Client-side JavaScript
├── web_ui_server.py    # Flask backend server
└── start_web_ui.sh     # Startup script
```

