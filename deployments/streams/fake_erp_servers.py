#!/usr/bin/env python3
"""
Fake ERP Backend Servers
Simulates downstream ERP systems that accept HTTP POST requests for master data
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import sys
from datetime import datetime
import xml.etree.ElementTree as ET
from urllib.parse import urlparse, parse_qs

# Force unbuffered output for real-time logging
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

class JSONERPHandler(BaseHTTPRequestHandler):
    """ERP system that accepts JSON format master data"""
    
    def do_POST(self):
        if self.path == '/erp/json/receive':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                parsed_data = json.loads(post_data.decode('utf-8'))
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                # Handle both single items (dict) and batches (list)
                items = parsed_data if isinstance(parsed_data, list) else [parsed_data]
                
                print(f"\n[{timestamp}] JSON ERP Received Master Data ({len(items)} item(s)):")
                
                processed_items = []
                for data in items:
                    if not isinstance(data, dict):
                        print(f"  ⚠ Skipping invalid item (not a dict): {type(data).__name__}")
                        continue
                    
                    print(f"  Item ID: {data.get('itemId', 'N/A')}")
                    print(f"  Name: {data.get('name', 'N/A')}")
                    print(f"  Category: {data.get('category', 'N/A')}")
                    print(f"  Price: ${data.get('price', 'N/A')}")
                    print(f"  Status: {data.get('status', 'N/A')}")
                    
                    processed_items.append({
                        "itemId": data.get('itemId')
                    })
                
                # Send success response
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                response = {
                    "status": "received",
                    "message": "Master data received successfully",
                    "count": len(processed_items),
                    "items": processed_items if len(processed_items) > 1 else processed_items[0] if processed_items else None,
                    "timestamp": timestamp
                }
                self.wfile.write(json.dumps(response).encode('utf-8'))
                
            except json.JSONDecodeError as e:
                print(f"\n[{datetime.now()}] JSON ERP Error: Invalid JSON - {e}")
                print(f"  Body was: {post_data.decode('utf-8', errors='ignore')[:500]}")
                self.send_response(400)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_response = {"error": "Invalid JSON format", "message": str(e)}
                self.wfile.write(json.dumps(error_response).encode('utf-8'))
            except Exception as e:
                print(f"\n[{datetime.now()}] JSON ERP Unexpected Error: {type(e).__name__} - {e}")
                import traceback
                traceback.print_exc()
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_response = {"error": "Internal server error", "message": str(e)}
                self.wfile.write(json.dumps(error_response).encode('utf-8'))
        else:
            print(f"\n[{datetime.now()}] JSON ERP: 404 - Path not found: {self.path}")
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress default logging to keep output clean
        pass


class XMLERPHandler(BaseHTTPRequestHandler):
    """ERP system that accepts XML format master data"""
    
    def do_POST(self):
        if self.path == '/erp/xml/receive':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                xml_string = post_data.decode('utf-8')
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                print(f"\n[{timestamp}] XML ERP Received Master Data:")
                print(f"  Raw XML:\n{xml_string[:200]}...")
                
                # Try to parse XML
                try:
                    root = ET.fromstring(xml_string)
                    item_id = root.find('itemId')
                    name = root.find('name')
                    category = root.find('category')
                    price = root.find('price')
                    
                    if item_id is not None:
                        print(f"  Item ID: {item_id.text}")
                    if name is not None:
                        print(f"  Name: {name.text}")
                    if category is not None:
                        print(f"  Category: {category.text}")
                    if price is not None:
                        print(f"  Price: ${price.text}")
                except ET.ParseError:
                    print(f"  (XML parsing skipped, but data received)")
                
                # Send success response
                self.send_response(200)
                self.send_header('Content-Type', 'application/xml')
                self.end_headers()
                response_xml = f"""<?xml version="1.0"?>
<response>
    <status>received</status>
    <message>Master data received successfully</message>
    <timestamp>{timestamp}</timestamp>
</response>"""
                self.wfile.write(response_xml.encode('utf-8'))
                
            except Exception as e:
                print(f"\n[{datetime.now()}] XML ERP Error: {e}")
                self.send_response(400)
                self.send_header('Content-Type', 'application/xml')
                self.end_headers()
                error_xml = f"""<?xml version="1.0"?>
<error>
    <message>{str(e)}</message>
</error>"""
                self.wfile.write(error_xml.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress default logging to keep output clean
        pass


class FilteredERPHandler(BaseHTTPRequestHandler):
    """ERP system that receives filtered master data (Electronics category only)"""
    
    def do_POST(self):
        if self.path == '/erp/filtered/receive':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                parsed_data = json.loads(post_data.decode('utf-8'))
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                # Handle both single items (dict) and batches (list)
                items = parsed_data if isinstance(parsed_data, list) else [parsed_data]
                
                print(f"\n[{timestamp}] Filtered ERP Received Master Data ({len(items)} item(s)):")
                
                processed_items = []
                for data in items:
                    if not isinstance(data, dict):
                        print(f"  ⚠ Skipping invalid item (not a dict): {type(data).__name__}")
                        continue
                    
                    category = data.get('category', '')
                    
                    print(f"  Item ID: {data.get('itemId', 'N/A')}")
                    print(f"  Name: {data.get('name', 'N/A')}")
                    print(f"  Category: {category} (filtered: Electronics only)")
                    print(f"  Price: ${data.get('price', 'N/A')}")
                    
                    # Verify it's Electronics category (should be filtered already)
                    if category.lower() != 'electronics':
                        print(f"  ⚠ WARNING: Received non-Electronics item (should have been filtered)")
                    
                    processed_items.append({
                        "itemId": data.get('itemId'),
                        "category": category
                    })
                
                # Send success response
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                response = {
                    "status": "received",
                    "message": "Filtered master data received successfully",
                    "count": len(processed_items),
                    "items": processed_items if len(processed_items) > 1 else processed_items[0] if processed_items else None,
                    "timestamp": timestamp
                }
                self.wfile.write(json.dumps(response).encode('utf-8'))
                
            except json.JSONDecodeError as e:
                print(f"\n[{datetime.now()}] Filtered ERP Error: Invalid JSON - {e}")
                self.send_response(400)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_response = {"error": "Invalid JSON format", "message": str(e)}
                self.wfile.write(json.dumps(error_response).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress default logging to keep output clean
        pass


def run_json_erp_server(port=8001):
    """Start JSON ERP server"""
    server = HTTPServer(('0.0.0.0', port), JSONERPHandler)
    print(f"JSON ERP Server started on http://localhost:{port}/erp/json/receive")
    print("Ready to receive master data in JSON format...")
    print("Press CTRL+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\nJSON ERP Server stopped")
        server.shutdown()


def run_xml_erp_server(port=8002):
    """Start XML ERP server"""
    server = HTTPServer(('0.0.0.0', port), XMLERPHandler)
    print(f"XML ERP Server started on http://localhost:{port}/erp/xml/receive")
    print("Ready to receive master data in XML format...")
    print("Press CTRL+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\nXML ERP Server stopped")
        server.shutdown()


def run_filtered_erp_server(port=8003):
    """Start Filtered ERP server"""
    server = HTTPServer(('0.0.0.0', port), FilteredERPHandler)
    print(f"Filtered ERP Server started on http://localhost:{port}/erp/filtered/receive")
    print("Ready to receive filtered master data (Electronics category only)...")
    print("Press CTRL+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\nFiltered ERP Server stopped")
        server.shutdown()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 fake_erp_servers.py [json|xml|filtered|all]")
        print("\nOptions:")
        print("  json      - Start JSON ERP server (port 8001)")
        print("  xml       - Start XML ERP server (port 8002)")
        print("  filtered  - Start Filtered ERP server (port 8003)")
        print("  all       - Start all three servers (requires multiple terminals)")
        sys.exit(1)
    
    mode = sys.argv[1].lower()
    
    if mode == 'json':
        run_json_erp_server()
    elif mode == 'xml':
        run_xml_erp_server()
    elif mode == 'filtered':
        run_filtered_erp_server()
    elif mode == 'all':
        print("To run all servers, start them in separate terminals:")
        print("  Terminal 1: python3 fake_erp_servers.py json")
        print("  Terminal 2: python3 fake_erp_servers.py xml")
        print("  Terminal 3: python3 fake_erp_servers.py filtered")
        sys.exit(1)
    else:
        print(f"Unknown mode: {mode}")
        sys.exit(1)

