#!/usr/bin/env python3
"""
customer-bot.py — minimal AI Studio-governed bot.

Demonstrates the "Build me a Slack/CS bot with tools" story for Act 2 of the
AI Studio three-act demo. Roughly 90 lines including MCP session handshake
and dynamic tool discovery. Drop a Slack / WebSocket / HTTP handler around
`chat()` and ship.

Two governed endpoints, one App credential:
  - LLM calls    : http://localhost:9090/llm/call/<llm-slug>/v1/messages
  - Tool catalog : http://localhost:9090/tools/<tool-slug>/mcp   (MCP streamable HTTP)

Header conventions (asymmetric — flagged in the demo script):
  - LLM routes  : Authorization: Bearer <app-secret>     (Anthropic SDK auth_token=)
  - Tool routes : Authorization: <app-secret>            (raw, no Bearer prefix)

MCP transport handshake (per spec):
  1. POST `initialize`     -> server returns 200 + Mcp-Session-Id header
  2. POST `notifications/initialized` (no id, no response expected)
  3. Subsequent calls MUST include the Mcp-Session-Id header

Discovery posture:
  - Tool slugs the App can use are taken from env (one bootstrap per App config change).
  - Operations within each tool are discovered dynamically via MCP `tools/list` at startup.

Usage:
    export TYK_APP_SECRET=<from AI Studio App detail page>
    python3 -m venv .venv && source .venv/bin/activate
    pip install anthropic requests
    python customer-bot.py "What headers is the bot using?"
    python customer-bot.py "Look up John Doe DOB 1980-02-15"   # PII filter intervenes
"""
import os
import sys
import uuid
import requests
from anthropic import Anthropic, BadRequestError

APP_SECRET = os.environ["TYK_APP_SECRET"]
GATEWAY    = os.environ.get("AI_STUDIO_URL", "http://localhost:9090")
LLM_SLUG   = os.environ.get("LLM_SLUG",      "self-hosted-claude-sdk")
TOOL_SLUGS = os.environ.get("TOOL_SLUGS",    "httpbin-api").split(",")
MODEL      = os.environ.get("MODEL",         "claude-sonnet-4-5-20250929")

llm = Anthropic(base_url=f"{GATEWAY}/llm/call/{LLM_SLUG}", auth_token=APP_SECRET)

_BASE_HEADERS = {
    "Authorization": APP_SECRET,                          # raw, no Bearer
    "Content-Type":  "application/json",
    "Accept":        "application/json, text/event-stream",
}
_sessions: dict[str, str] = {}   # slug -> Mcp-Session-Id


def _post(slug: str, body: dict, session_id: str | None = None) -> requests.Response:
    headers = dict(_BASE_HEADERS)
    if session_id:
        headers["Mcp-Session-Id"] = session_id
    r = requests.post(f"{GATEWAY}/tools/{slug}/mcp", headers=headers, json=body, timeout=30)
    r.raise_for_status()
    return r


def _ensure_session(slug: str) -> str:
    """Initialize MCP session if we don't have one for this slug yet."""
    if slug in _sessions:
        return _sessions[slug]
    init = _post(slug, {
        "jsonrpc": "2.0", "id": str(uuid.uuid4()), "method": "initialize",
        "params": {"protocolVersion": "2025-06-18",
                   "capabilities": {},
                   "clientInfo": {"name": "customer-bot", "version": "0.1"}},
    })
    sid = init.headers["Mcp-Session-Id"]
    _post(slug, {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}, sid)
    _sessions[slug] = sid
    return sid


def _mcp(slug: str, method: str, params: dict | None = None) -> dict:
    """JSON-RPC call against AI Studio's per-tool MCP endpoint, with session handshake."""
    sid = _ensure_session(slug)
    r = _post(slug, {"jsonrpc": "2.0", "id": str(uuid.uuid4()),
                     "method": method, "params": params or {}}, sid)
    return r.json()["result"]


def discover_tools() -> tuple[list[dict], dict[str, str]]:
    """Ask each AI Studio MCP server what tools it offers; return Anthropic-shaped list."""
    catalogue, slug_for = [], {}
    for slug in TOOL_SLUGS:
        for t in _mcp(slug, "tools/list").get("tools", []):
            catalogue.append({
                "name": t["name"],
                "description": t.get("description", ""),
                "input_schema": t.get("inputSchema", {"type": "object", "properties": {}}),
            })
            slug_for[t["name"]] = slug
    return catalogue, slug_for


def chat(user_msg: str) -> str:
    tools, tool_owner = discover_tools()
    msgs = [{"role": "user", "content": user_msg}]
    while True:
        try:
            resp = llm.messages.create(model=MODEL, max_tokens=512, tools=tools, messages=msgs)
        except BadRequestError as e:
            # AI Studio gateway filter intervened (PII, prompt-injection, etc.).
            # In a real bot this would map to a polite "I can't help with that" reply.
            body = getattr(e, "body", None) or {}
            return f"[blocked by policy] {body.get('message', str(e))}"
        msgs.append({"role": "assistant", "content": resp.content})
        tool_uses = [b for b in resp.content if b.type == "tool_use"]
        if not tool_uses:
            return next((b.text for b in resp.content if b.type == "text"), "")
        msgs.append({"role": "user", "content": [
            {"type": "tool_result",
             "tool_use_id": t.id,
             "content": str(_mcp(tool_owner[t.name], "tools/call",
                                 {"name": t.name, "arguments": t.input}))}
            for t in tool_uses
        ]})


if __name__ == "__main__":
    print(chat(" ".join(sys.argv[1:]) or "Hello"))
