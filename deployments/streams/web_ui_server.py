#!/usr/bin/env python3
"""
Web UI Server for Kafka Master Data Streaming Demo
Serves the web UI and provides log tailing API endpoints
"""

import os
import sys
from flask import Flask, Response, jsonify, send_from_directory, request
import threading
import time
import json
import urllib.request
import urllib.error

# Try to import requests for better SSE streaming support
try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False
    print("Warning: requests library not available. SSE proxying will use urllib (may be less reliable).")
    print("Install with: pip3 install requests")

# Try to import CORS, but make it optional
try:
    from flask_cors import CORS
    CORS_AVAILABLE = True
except ImportError:
    CORS_AVAILABLE = False
    print("Warning: flask-cors not installed. CORS support disabled.")

app = Flask(__name__, static_folder='web_ui', static_url_path='')
if CORS_AVAILABLE:
    CORS(app)  # Enable CORS for all routes

# Log file paths
LOG_FILES = {
    'json': '/tmp/erp_json.log',
    'xml': '/tmp/erp_xml.log',
    'filtered': '/tmp/erp_filtered.log'
}

# Store last read positions for each log file
log_positions = {key: 0 for key in LOG_FILES.keys()}

# Tyk Gateway configuration
TYK_GATEWAY_URL = os.getenv('TYK_GATEWAY_URL', 'http://tyk-gateway.localhost:8080')
PRODUCER_ENDPOINT = f'{TYK_GATEWAY_URL}/streams-master-data/producer'

# SSE Stream endpoints mapping
SSE_ENDPOINTS = {
    'json': f'{TYK_GATEWAY_URL}/streams-master-data-json/stream',
    'xml': f'{TYK_GATEWAY_URL}/streams-master-data-xml/stream',
    'filtered': f'{TYK_GATEWAY_URL}/streams-master-data-filtered/stream'
}


def tail_log_file(filepath, last_position=0):
    """Read new content from log file since last_position"""
    try:
        if not os.path.exists(filepath):
            return '', 0
        
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            f.seek(last_position)
            new_content = f.read()
            new_position = f.tell()
            return new_content, new_position
    except Exception as e:
        return f"Error reading log: {str(e)}\n", last_position


@app.route('/')
def index():
    """Serve the main UI page"""
    return send_from_directory('web_ui', 'index.html')


@app.route('/api/logs/<log_type>')
def get_logs(log_type):
    """Get tail of log file for specified type"""
    if log_type not in LOG_FILES:
        return jsonify({'error': 'Invalid log type'}), 400
    
    filepath = LOG_FILES[log_type]
    last_pos = log_positions.get(log_type, 0)
    
    new_content, new_position = tail_log_file(filepath, last_pos)
    log_positions[log_type] = new_position
    
    return jsonify({
        'content': new_content,
        'position': new_position,
        'exists': os.path.exists(filepath)
    })


@app.route('/api/logs/<log_type>/reset', methods=['POST', 'GET'])
def reset_log_position(log_type):
    """Reset log position and optionally clear the log file"""
    if log_type not in LOG_FILES:
        return jsonify({'error': 'Invalid log type'}), 400
    
    filepath = LOG_FILES[log_type]
    
    # Clear the log file by truncating it
    try:
        if os.path.exists(filepath):
            # Truncate the file to 0 bytes (clear it)
            with open(filepath, 'w') as f:
                f.truncate(0)
    except Exception as e:
        return jsonify({'error': f'Failed to clear log file: {str(e)}'}), 500
    
    # Reset the position tracking
    if log_type in log_positions:
        log_positions[log_type] = 0
    
    return jsonify({'status': 'cleared', 'message': 'Log file cleared successfully'})


@app.route('/api/producer', methods=['POST', 'OPTIONS'])
def proxy_producer():
    """Proxy endpoint for producer API to avoid CORS issues"""
    if request.method == 'OPTIONS':
        # Handle preflight request
        response = Response()
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'POST')
        return response
    
    try:
        # Get the JSON payload from the request
        payload = request.get_json()
        if not payload:
            return jsonify({'error': 'No JSON payload provided'}), 400
        
        # Convert payload to JSON string
        json_data = json.dumps(payload).encode('utf-8')
        
        # Create request to Tyk Gateway
        req = urllib.request.Request(
            PRODUCER_ENDPOINT,
            data=json_data,
            headers={
                'Content-Type': 'application/json',
                'Content-Length': len(json_data)
            },
            method='POST'
        )
        
        # Make the request
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                status_code = response.getcode()
                response_data = response.read().decode('utf-8')
                
                # Return the response
                flask_response = Response(
                    response=json.dumps({
                        'status': 'success',
                        'http_code': status_code,
                        'message': 'Data posted successfully' if status_code == 200 else response_data
                    }),
                    status=status_code,
                    mimetype='application/json'
                )
                flask_response.headers.add('Access-Control-Allow-Origin', '*')
                return flask_response
                
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8')
            return jsonify({
                'error': f'HTTP {e.code}: {e.reason}',
                'details': error_body,
                'endpoint': PRODUCER_ENDPOINT
            }), e.code
            
        except urllib.error.URLError as e:
            return jsonify({
                'error': 'Failed to connect to Tyk Gateway',
                'details': str(e.reason),
                'endpoint': PRODUCER_ENDPOINT,
                'suggestion': 'Check if Tyk Gateway is running and the endpoint is correct'
            }), 503
            
    except Exception as e:
        return jsonify({
            'error': 'Internal server error',
            'details': str(e)
        }), 500


@app.route('/api/stream/<stream_type>')
def proxy_sse_stream(stream_type):
    """Proxy SSE stream from Tyk Gateway to browser to avoid CORS issues"""
    if stream_type not in SSE_ENDPOINTS:
        return jsonify({'error': f'Invalid stream type: {stream_type}'}), 400
    
    stream_url = SSE_ENDPOINTS[stream_type]
    
    def generate():
        """Generator function to stream SSE data from Tyk Gateway"""
        if REQUESTS_AVAILABLE:
            # Use requests library for better streaming support
            try:
                # Stream from Tyk Gateway using requests with stream=True
                with requests.get(
                    stream_url,
                    headers={
                        'Accept': 'text/event-stream',
                        'Cache-Control': 'no-cache'
                    },
                    stream=True,
                    timeout=30  # Initial connection timeout
                ) as r:
                    r.raise_for_status()
                    
                    # Send initial connection confirmation
                    yield f"data: {{\"status\": \"connected\", \"stream\": \"{stream_type}\"}}\n\n".encode('utf-8')
                    
                    # Stream data from Tyk Gateway - forward as-is
                    try:
                        buffer = b''
                        for chunk in r.iter_content(chunk_size=8192, decode_unicode=False):
                            if chunk:
                                buffer += chunk
                                
                                # Process complete lines (ending with newline)
                                while b'\n' in buffer:
                                    line, buffer = buffer.split(b'\n', 1)
                                    
                                    if line.strip():
                                        line_stripped = line.strip()
                                        
                                        # Skip our own status message
                                        if b'{"status": "connected"' in line_stripped:
                                            continue
                                        
                                        # Check if already SSE formatted
                                        if line_stripped.startswith(b'data:'):
                                            yield line_stripped + b'\n\n'
                                        else:
                                            yield b'data: ' + line_stripped + b'\n\n'
                            else:
                                # Connection ended - flush any remaining buffer
                                if buffer.strip():
                                    remaining = buffer.strip()
                                    if not remaining.startswith(b'data:'):
                                        yield b'data: ' + remaining + b'\n\n'
                                    else:
                                        yield remaining + b'\n\n'
                                break
                    except Exception as stream_error:
                        error_msg = f"data: {{\"error\": \"Stream error: {str(stream_error)}\"}}\n\n"
                        yield error_msg.encode('utf-8')
                            
            except requests.exceptions.HTTPError as e:
                error_msg = f"data: {{\"error\": \"HTTP {e.response.status_code}: {e.response.reason}\"}}\n\n"
                yield error_msg.encode('utf-8')
            except requests.exceptions.Timeout as e:
                error_msg = f"data: {{\"error\": \"Connection timeout to Tyk Gateway\"}}\n\n"
                yield error_msg.encode('utf-8')
            except requests.exceptions.RequestException as e:
                error_msg = f"data: {{\"error\": \"Connection failed: {str(e)}\"}}\n\n"
                yield error_msg.encode('utf-8')
            except Exception as e:
                error_msg = f"data: {{\"error\": \"Unexpected error: {str(e)}\"}}\n\n"
                yield error_msg.encode('utf-8')
        else:
            # Fallback to urllib if requests is not available
            response = None
            try:
                req = urllib.request.Request(
                    stream_url,
                    headers={
                        'Accept': 'text/event-stream',
                        'Cache-Control': 'no-cache'
                    }
                )
                
                response = urllib.request.urlopen(req, timeout=None)
                yield f"data: {{\"status\": \"connected\", \"stream\": \"{stream_type}\"}}\n\n".encode('utf-8')
                
                chunk_size = 1024
                while True:
                    try:
                        chunk = response.read(chunk_size)
                        if not chunk:
                            break
                        yield chunk
                    except (ConnectionError, BrokenPipeError) as e:
                        break
                        
            except urllib.error.HTTPError as e:
                error_body = e.read().decode('utf-8', errors='ignore') if hasattr(e, 'read') else ''
                error_msg = f"data: {{\"error\": \"HTTP {e.code}: {e.reason}\", \"stream\": \"{stream_type}\"}}\n\n"
                yield error_msg.encode('utf-8')
            except urllib.error.URLError as e:
                error_msg = f"data: {{\"error\": \"Connection failed: {str(e.reason)}\", \"stream\": \"{stream_type}\"}}\n\n"
                yield error_msg.encode('utf-8')
            except Exception as e:
                error_msg = f"data: {{\"error\": \"Unexpected error: {str(e)}\", \"stream\": \"{stream_type}\"}}\n\n"
                yield error_msg.encode('utf-8')
            finally:
                if response:
                    try:
                        response.close()
                    except:
                        pass
    
    # Return streaming response with SSE headers
    return Response(
        generate(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache, no-transform',
            'X-Accel-Buffering': 'no',  # Disable buffering in nginx if present
            'Connection': 'keep-alive'
        }
    )


@app.route('/api/health')
def health():
    """Health check endpoint"""
    log_status = {}
    for log_type, filepath in LOG_FILES.items():
        log_status[log_type] = {
            'exists': os.path.exists(filepath),
            'size': os.path.getsize(filepath) if os.path.exists(filepath) else 0
        }
    
    # Check Tyk Gateway connectivity
    tyk_status = {'reachable': False, 'endpoint': PRODUCER_ENDPOINT}
    try:
        req = urllib.request.Request(TYK_GATEWAY_URL, method='HEAD')
        with urllib.request.urlopen(req, timeout=3):
            tyk_status['reachable'] = True
    except:
        pass
    
    return jsonify({
        'status': 'ok',
        'logs': log_status,
        'tyk_gateway': tyk_status
    })


if __name__ == '__main__':
    print("=" * 60)
    print("Kafka Master Data Streaming - Web UI Server")
    print("=" * 60)
    print("\nStarting web UI server on http://localhost:8888")
    print(f"\nTyk Gateway: {TYK_GATEWAY_URL}")
    print(f"Producer Proxy: /api/producer -> {PRODUCER_ENDPOINT}")
    print("\nSSE Stream Proxies:")
    for stream_type, endpoint in SSE_ENDPOINTS.items():
        print(f"  /api/stream/{stream_type} -> {endpoint}")
    print("\nAvailable log files:")
    for log_type, filepath in LOG_FILES.items():
        exists = "✓" if os.path.exists(filepath) else "✗"
        print(f"  {exists} {log_type.upper()}: {filepath}")
    print("\nOpen http://localhost:8888 in your browser")
    print("Press CTRL+C to stop the server\n")
    print("=" * 60)
    
    # Run Flask app (disable request logging to reduce console output)
    import logging
    log = logging.getLogger('werkzeug')
    log.setLevel(logging.ERROR)  # Only show errors, not every request
    
    app.run(host='0.0.0.0', port=8888, debug=False, threaded=True)

