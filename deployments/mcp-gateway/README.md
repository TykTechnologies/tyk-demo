# MCP Gateway

Supporting infrastructure for the Tyk MCP Gateway demo (Tyk 5.13+).

This deployment provisions the services needed to run the live MCP demo:

- **Mock MCP Server** — [tyk-mock-mcp-server](https://github.com/TykTechnologies/tyk-mock-mcp-server), exposing 15 tools across 6 categories. The upstream the demo proxies to.
- **MCP Inspector** — the official [`@modelcontextprotocol/inspector`](https://www.npmjs.com/package/@modelcontextprotocol/inspector), used as the MCP client in the demo.

It deliberately **does not** bootstrap any MCP proxies, policies, or keys into the Dashboard — the demo script walks through creating all of those live.

## Prerequisites

1. **Tyk 5.13 or later.** MCP Gateway support ships in 5.13. Set these in your `.env` before running `./up.sh`:

   ```
   DASHBOARD_VERSION=v5.13.0
   GATEWAY_VERSION=v5.13.0
   ```

2. A valid Tyk Dashboard licence in `.env` (already required by the base `tyk` deployment).

## Usage

From the tyk-demo repo root:

```shell
./up.sh mcp-gateway otel-jaeger
```

This brings up the base Tyk deployment plus the Mock MCP Server and MCP Inspector.

When bootstrap completes you should have:

| Service            | URL                              | Notes |
|--------------------|----------------------------------|-------|
| Tyk Dashboard      | http://localhost:3000            | Standard base credentials |
| Mock MCP Server    | http://localhost:7878            | Health: `/health`, MCP: `/mcp` |
| MCP Inspector      | http://localhost:6274            | Browser UI |

## Running the Demo

1. Log in to the Dashboard at http://localhost:3000.
2. Open MCP Inspector at http://localhost:6274 in a separate tab.
3. Create a new **MCP Proxy** in the Dashboard pointing at `http://mcp-mock-server:7878` (use the Docker service name so the Tyk Gateway can reach the upstream on the internal network).
4. Copy the Gateway-exposed proxy URL, append `/mcp`, and connect from Inspector. The Inspector container is on the same Docker network as the Gateway, so the Gateway URL works directly.

There is an MCP Proxy example in the `data` dir

## Networking Notes

Both supporting services join the base `tyk` network, so the Tyk Gateway can reach the mock server as `http://mcp-mock-server:7878` and the Inspector's proxy can reach the Gateway as `http://tyk-gateway:8080`. Ports are also mapped to the host for browser access and local debugging.

When entering the upstream URL in the Dashboard's MCP Proxy wizard, use the **service name** (`http://mcp-mock-server:7878`) rather than `http://localhost:7878` — the Tyk Gateway runs inside Docker and `localhost` there means the Gateway container itself.

## Teardown

```shell
./down.sh
```

The base `down.sh` handles all services brought up by `up.sh`.
