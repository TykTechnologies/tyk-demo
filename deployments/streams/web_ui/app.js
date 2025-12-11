// Configuration
const API_BASE_URL = window.location.origin;
const PRODUCER_URL = `${API_BASE_URL}/api/producer`;
// Use proxied SSE endpoints to avoid CORS issues
const SSE_URLS = {
    json: `${API_BASE_URL}/api/stream/json`,
    xml: `${API_BASE_URL}/api/stream/xml`,
    filtered: `${API_BASE_URL}/api/stream/filtered`
};

const LOG_API_URL = API_BASE_URL;
const LOG_POLL_INTERVAL = 1000;

// State management
const consumerStates = {
    json: { connected: false, eventSource: null, failed: false },
    xml: { connected: false, eventSource: null, failed: false },
    filtered: { connected: false, eventSource: null, failed: false }
};

const logStates = {
    json: { polling: false, interval: null },
    xml: { polling: false, interval: null },
    filtered: { polling: false, interval: null }
};

// Producer Form Handler
document.getElementById('producerForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const submitBtn = document.getElementById('submitBtn');
    const statusDiv = document.getElementById('producerStatus');
    
    const payload = {
        itemId: document.getElementById('itemId').value,
        name: document.getElementById('name').value,
        category: document.getElementById('category').value,
        price: parseFloat(document.getElementById('price').value)
    };
    
    const description = document.getElementById('description').value.trim();
    if (description) payload.description = description;
    
    const status = document.getElementById('status').value.trim();
    if (status) payload.status = status;
    
    submitBtn.disabled = true;
    submitBtn.textContent = 'Posting...';
    statusDiv.className = 'status-message';
    statusDiv.textContent = '';
    statusDiv.style.display = 'none';
    
    try {
        const response = await fetch(PRODUCER_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        const responseData = await response.json();
        
        if (response.ok && response.status >= 200 && response.status < 300) {
            statusDiv.className = 'status-message success';
            statusDiv.textContent = `✓ Successfully posted! (HTTP ${responseData.http_code || response.status})`;
            statusDiv.style.display = 'block';
        } else {
            const errorMsg = responseData.error || responseData.message || 'Unknown error';
            const details = responseData.details ? ` - ${responseData.details}` : '';
            statusDiv.className = 'status-message error';
            statusDiv.innerHTML = `✗ Error: ${errorMsg}${details}`.replace(/\n/g, '<br>');
            statusDiv.style.display = 'block';
        }
    } catch (error) {
        statusDiv.className = 'status-message error';
        statusDiv.textContent = `✗ Connection error: ${error.message}`;
        statusDiv.style.display = 'block';
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Post to Producer';
    }
});

// Show JSON Preview
document.getElementById('formatBtn').addEventListener('click', () => {
    const preview = document.getElementById('jsonPreview');
    const output = document.getElementById('jsonOutput');
    
    const payload = {
        itemId: document.getElementById('itemId').value,
        name: document.getElementById('name').value,
        category: document.getElementById('category').value,
        price: parseFloat(document.getElementById('price').value)
    };
    
    const description = document.getElementById('description').value.trim();
    if (description) payload.description = description;
    
    const status = document.getElementById('status').value.trim();
    if (status) payload.status = status;
    
    output.textContent = JSON.stringify(payload, null, 2);
    preview.style.display = preview.style.display === 'none' ? 'block' : 'none';
});

// SSE Consumer Functions
function toggleConsumer(type) {
    const state = consumerStates[type];
    const statusEl = document.getElementById(`${type}Status`);
    const streamEl = document.getElementById(`${type}Stream`);
    const btn = event.target;
    
    // If in failed state, restart instead of stopping
    if (state.failed) {
        state.failed = false;
        state.connected = false;
        if (state.eventSource) {
            state.eventSource.close();
            state.eventSource = null;
        }
        connectConsumer(type);
        btn.textContent = 'Stop';
        btn.classList.add('stop');
        btn.classList.remove('restart');
        return;
    }
    
    if (state.connected) {
        if (state.eventSource) {
            state.eventSource.close();
            state.eventSource = null;
        }
        state.connected = false;
        state.failed = false;
        statusEl.querySelector('.status-dot').className = 'status-dot disconnected';
        statusEl.querySelector('span:last-child').textContent = 'Disconnected';
        btn.textContent = 'Start';
        btn.classList.remove('stop');
        btn.classList.remove('restart');
        streamEl.innerHTML = '<p class="placeholder">Click "Start" to begin streaming...</p>';
    } else {
        connectConsumer(type);
        btn.textContent = 'Stop';
        btn.classList.add('stop');
        btn.classList.remove('restart');
    }
}

function connectConsumer(type) {
    const state = consumerStates[type];
    const statusEl = document.getElementById(`${type}Status`);
    const streamEl = document.getElementById(`${type}Stream`);
    const url = SSE_URLS[type];
    
    streamEl.innerHTML = '';
    
    try {
        console.log(`Connecting to ${type} stream at: ${url}`);
        const eventSource = new EventSource(url);
        state.eventSource = eventSource;
        
        statusEl.querySelector('.status-dot').className = 'status-dot streaming';
        statusEl.querySelector('span:last-child').textContent = 'Connecting...';
        
        eventSource.onopen = () => {
            state.connected = true;
            state.failed = false; // Clear failed state on successful connection
            statusEl.querySelector('.status-dot').className = 'status-dot connected';
            statusEl.querySelector('span:last-child').textContent = 'Connected - Waiting for data';
            
            // Update button back to Stop
            const statusContainer = document.getElementById(`${type}Status`);
            if (statusContainer) {
                const btn = statusContainer.parentElement.querySelector('button.toggle-btn');
                if (btn) {
                    btn.textContent = 'Stop';
                    btn.classList.add('stop');
                    btn.classList.remove('restart');
                }
            }
            
            console.log(`✓ Connected to ${type} stream`);
            
            // Show waiting message
            if (streamEl.querySelector('.placeholder')) {
                streamEl.innerHTML = `
                    <p class="placeholder" style="color: #2196f3;">
                        ✓ Connected to stream<br>
                        <small>Waiting for messages from Kafka...<br>
                        Post data using the Producer form above to see messages appear here.</small>
                    </p>
                `;
            }
        };
        
        eventSource.onmessage = (event) => {
            if (streamEl.querySelector('.placeholder')) {
                streamEl.innerHTML = '';
            }
            
            let content = event.data;
            
            if (type === 'xml') {
                // Display XML as-is with proper HTML escaping
                const messageDiv = document.createElement('div');
                messageDiv.className = `message ${type}`;
                messageDiv.innerHTML = `<pre>${escapeHtml(content)}</pre>`;
                
                streamEl.appendChild(messageDiv);
                streamEl.scrollTop = streamEl.scrollHeight;
            } else {
                const messageDiv = document.createElement('div');
                messageDiv.className = `message ${type}`;
                
                try {
                    const jsonObj = JSON.parse(content);
                    messageDiv.innerHTML = `<pre>${JSON.stringify(jsonObj, null, 2)}</pre>`;
                } catch (e) {
                    messageDiv.innerHTML = `<pre>${escapeHtml(content)}</pre>`;
                }
                
                streamEl.appendChild(messageDiv);
                streamEl.scrollTop = streamEl.scrollHeight;
            }
        };
        
        eventSource.onerror = (error) => {
            console.error(`SSE error for ${type}:`, error, 'readyState:', eventSource.readyState);
            const wasConnected = state.connected;
            
            // Check readyState to determine error type
            if (eventSource.readyState === EventSource.CONNECTING) {
                // Never connected - this is a real connection failure
                state.connected = false;
                state.failed = true;
                statusEl.querySelector('.status-dot').className = 'status-dot disconnected';
                statusEl.querySelector('span:last-child').textContent = 'Connection failed';
                
                // Update button to show Restart
                const statusContainer = document.getElementById(`${type}Status`);
                if (statusContainer) {
                    const btn = statusContainer.parentElement.querySelector('button.toggle-btn');
                    if (btn) {
                        btn.textContent = 'Restart';
                        btn.classList.remove('stop');
                        btn.classList.add('restart');
                    }
                }
                
                streamEl.innerHTML = `
                    <p class="placeholder" style="color: #f44336;">
                        ✗ Failed to connect to ${type} stream.<br>
                        <small>Click "Restart" to try again.<br><br>
                        Possible causes:<br>
                        - API not loaded (check with ./verify_apis_loaded.sh)<br>
                        - CORS not configured (check API definitions)<br>
                        - Tyk Gateway not running<br>
                        - Network error<br>
                        Check browser console (F12) for details.</small>
                    </p>
                `;
                if (eventSource) {
                    eventSource.close();
                    state.eventSource = null;
                }
            } else if (eventSource.readyState === EventSource.OPEN) {
                // Connection is open - errors here are usually just waiting for data
                // Don't change status, just log it
                console.log(`Stream is connected, waiting for data...`);
            } else if (eventSource.readyState === EventSource.CLOSED) {
                // Connection was closed
                state.connected = false;
                statusEl.querySelector('.status-dot').className = 'status-dot disconnected';
                if (wasConnected) {
                    state.failed = true;
                    statusEl.querySelector('span:last-child').textContent = 'Connection lost';
                    
                    // Update button to show Restart after failed reconnection
                    setTimeout(() => {
                        if (!state.connected) {
                            const statusContainer = document.getElementById(`${type}Status`);
                            if (statusContainer) {
                                const btn = statusContainer.parentElement.querySelector('button.toggle-btn');
                                if (btn) {
                                    btn.textContent = 'Restart';
                                    btn.classList.remove('stop');
                                    btn.classList.add('restart');
                                }
                            }
                            statusEl.querySelector('span:last-child').textContent = 'Connection lost - Click Restart';
                        }
                    }, 5000); // Wait 5 seconds for auto-reconnect, then show Restart
                    
                    // Try to reconnect automatically first
                    setTimeout(() => {
                        if (!state.connected && state.eventSource) {
                            console.log(`Attempting to reconnect ${type} stream...`);
                            connectConsumer(type);
                        }
                    }, 3000);
                } else {
                    state.failed = true;
                    statusEl.querySelector('span:last-child').textContent = 'Connection closed';
                    
                    // Update button to show Restart
                    const statusContainer = document.getElementById(`${type}Status`);
                    if (statusContainer) {
                        const btn = statusContainer.parentElement.querySelector('button.toggle-btn');
                        if (btn) {
                            btn.textContent = 'Restart';
                            btn.classList.remove('stop');
                            btn.classList.add('restart');
                        }
                    }
                }
            }
        };
        
    } catch (error) {
        console.error(`Failed to create EventSource for ${type}:`, error);
        state.connected = false;
        state.failed = true;
        statusEl.querySelector('.status-dot').className = 'status-dot disconnected';
        statusEl.querySelector('span:last-child').textContent = 'Connection failed';
        
        // Update button to show Restart
        const statusContainer = document.getElementById(`${type}Status`);
        if (statusContainer) {
            const btn = statusContainer.parentElement.querySelector('button.toggle-btn');
            if (btn) {
                btn.textContent = 'Restart';
                btn.classList.remove('stop');
                btn.classList.add('restart');
            }
        }
        
        streamEl.innerHTML = `<p class="placeholder" style="color: #f44336;">Error: ${error.message}<br><small>Click "Restart" to try again.</small></p>`;
    }
}

// Log Tailing Functions
function toggleLog(type) {
    const state = logStates[type];
    const statusEl = document.getElementById(`${type}LogStatus`);
    const logEl = document.getElementById(`${type}Log`);
    const btn = event.target;
    
    if (state.polling) {
        if (state.interval) {
            clearInterval(state.interval);
            state.interval = null;
        }
        state.polling = false;
        statusEl.querySelector('.status-dot').className = 'status-dot';
        statusEl.querySelector('span:last-child').textContent = 'Stopped';
        btn.textContent = 'Start';
        btn.classList.remove('stop');
    } else {
        startLogPolling(type);
        btn.textContent = 'Stop';
        btn.classList.add('stop');
    }
}

function startLogPolling(type) {
    const state = logStates[type];
    const statusEl = document.getElementById(`${type}LogStatus`);
    const logEl = document.getElementById(`${type}Log`);
    
    state.polling = true;
    logEl.innerHTML = '';
    fetchLog(type);
    state.interval = setInterval(() => fetchLog(type), LOG_POLL_INTERVAL);
}

async function fetchLog(type) {
    const statusEl = document.getElementById(`${type}LogStatus`);
    const logEl = document.getElementById(`${type}Log`);
    
    try {
        const response = await fetch(`${LOG_API_URL}/api/logs/${type}`);
        const data = await response.json();
        
        if (data.error) {
            statusEl.querySelector('.status-dot').className = 'status-dot disconnected';
            statusEl.querySelector('span:last-child').textContent = 'Error';
            return;
        }
        
        if (!data.exists) {
            statusEl.querySelector('.status-dot').className = 'status-dot';
            statusEl.querySelector('span:last-child').textContent = 'Log file not found';
            if (logEl.innerHTML === '') {
                logEl.innerHTML = '<p class="placeholder">Log file does not exist. Start the ERP servers first.</p>';
            }
            return;
        }
        
        statusEl.querySelector('.status-dot').className = 'status-dot connected';
        statusEl.querySelector('span:last-child').textContent = 'Streaming';
        
        if (data.content) {
            if (logEl.querySelector('.placeholder')) {
                logEl.innerHTML = '';
            }
            
            const lines = data.content.split('\n').filter(line => line.trim());
            lines.forEach(line => {
                const logLine = document.createElement('div');
                logLine.className = 'log-line';
                
                if (line.toLowerCase().includes('error') || line.toLowerCase().includes('exception')) {
                    logLine.className += ' error';
                } else if (line.toLowerCase().includes('success') || line.toLowerCase().includes('received')) {
                    logLine.className += ' success';
                } else if (line.toLowerCase().includes('info') || line.toLowerCase().includes('started')) {
                    logLine.className += ' info';
                }
                
                logLine.textContent = line;
                logEl.appendChild(logLine);
            });
            
            logEl.scrollTop = logEl.scrollHeight;
        }
        
    } catch (error) {
        console.error(`Error fetching log for ${type}:`, error);
        statusEl.querySelector('.status-dot').className = 'status-dot disconnected';
        statusEl.querySelector('span:last-child').textContent = 'Connection error';
    }
}

function clearLog(type) {
    const logEl = document.getElementById(`${type}Log`);
    logEl.innerHTML = '<p class="placeholder">Clearing log file...</p>';
    
    fetch(`${LOG_API_URL}/api/logs/${type}/reset`, {
        method: 'POST'
    })
    .then(response => response.json())
    .then(data => {
        logEl.innerHTML = '<p class="placeholder">Log file cleared. Restart to continue viewing.</p>';
        console.log(`Log cleared: ${data.message || 'Success'}`);
    })
    .catch(error => {
        logEl.innerHTML = `<p class="placeholder" style="color: #f44336;">Error clearing log: ${error.message}</p>`;
        console.error('Error clearing log:', error);
    });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatXml(xmlString) {
    if (!xmlString || !xmlString.trim()) {
        return escapeHtml(xmlString || '');
    }
    
    let formatted = xmlString.trim();
    
    // Remove all existing whitespace between tags for clean formatting
    formatted = formatted.replace(/>\s+</g, '><');
    
    // Add newlines between tags for proper formatting
    formatted = formatted.replace(/>/g, '>\n');
    formatted = formatted.replace(/</g, '\n<');
    
    // Split into lines and clean up
    let lines = formatted.split('\n').map(line => line.trim()).filter(line => line);
    let indent = 0;
    const indentSize = 2;
    const result = [];
    
    for (let i = 0; i < lines.length; i++) {
        let line = lines[i];
        if (!line) continue;
        
        // Check if this is a closing tag
        const isClosingTag = /^<\/[^>]+>$/.test(line);
        // Check if this is a self-closing tag
        const isSelfClosing = /^<[^>]+\/>$/.test(line);
        // Check if this is an opening tag (not self-closing, not comment, not CDATA, not processing instruction)
        const isOpeningTag = /^<[^/!?][^>]*>$/.test(line) && !isSelfClosing && !line.startsWith('<?') && !line.startsWith('<!');
        
        // Decrease indent before adding closing tag
        if (isClosingTag) {
            indent = Math.max(0, indent - 1);
        }
        
        // Add the line with proper indentation
        const indentedLine = ' '.repeat(indent * indentSize) + line;
        result.push(indentedLine);
        
        // Increase indent after opening tags
        if (isOpeningTag) {
            indent++;
        }
    }
    
    // Join with newlines and escape HTML for safe display
    return escapeHtml(result.join('\n'));
}

window.addEventListener('beforeunload', () => {
    Object.values(consumerStates).forEach(state => {
        if (state.eventSource) {
            state.eventSource.close();
        }
    });
    Object.values(logStates).forEach(state => {
        if (state.interval) {
            clearInterval(state.interval);
        }
    });
});

