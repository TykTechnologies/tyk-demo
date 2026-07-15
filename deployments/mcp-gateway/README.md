# MCP Gateway

Supporting infrastructure for the Tyk MCP Gateway demo (Tyk 5.13+).

This deployment provisions the services needed to run the live MCP demo:

- **Mock MCP Server** — [tyk-mock-mcp-server](https://github.com/TykTechnologies/tyk-mock-mcp-server), exposing 15 tools across 6 categories. The upstream the demo proxies to.
- **MCP Inspector** — the official [`@modelcontextprotocol/inspector`](https://www.npmjs.com/package/@modelcontextprotocol/inspector), used as the MCP client in the demo.

It deliberately **does not** bootstrap any MCP proxies, policies, or keys into the Dashboard — the demo script walks through creating all of those live. An example OAS proxy definition is provided in `data/` (`mcp-proxy.yaml`, and `tyk-dashboard/apis/mock-mcp.json` in Dashboard API format) with listen path `/mock-mcp`.

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
./up.sh mcp-gateway opentelemetry-demo
```

This brings up the base Tyk deployment, the Mock MCP Server and MCP Inspector, plus the OpenTelemetry demo — whose Grafana carries the MCP metrics dashboard used in the observability chapter of the demo. If you only need the MCP basics, `./up.sh mcp-gateway` works standalone; you lose the Grafana portion of the story.

### Quick links

| Service            | URL                                    | Notes |
|--------------------|----------------------------------------|-------|
| Tyk Dashboard      | http://localhost:3000                  | Standard base credentials |
| Mock MCP Server    | http://localhost:7878                  | Health: `/health`, MCP: `/mcp`; from the Gateway: `http://mcp-mock-server:7878/mcp` |
| MCP Inspector      | http://localhost:6274                  | Connect to `http://tyk-gateway:8080/<your-proxy>/mcp` |
| Grafana (OTel demo)| http://localhost:8085/grafana/         | MCP metrics dashboard (requires `opentelemetry-demo`) |

## Demo Flow

The live demo runs in four chapters; nothing is pre-configured, everything is created in front of the audience.

1. **Create an MCP proxy — unified management.** Create (or import from `data/`) the Mock MCP proxy in the Dashboard's MCP section, alongside REST/GraphQL/Kafka APIs. It's defined as code in OAS format, so the GitOps workflow used for other APIs applies unchanged. Connect from MCP Inspector via the Gateway URL.
2. **Add authentication.** Edit the proxy, enable Auth Token, save — the open connection now returns 403. Create a security policy and a key under it; the same policy model as every other API type.
3. **Filtered discovery & per-tool rate limits.** Block a tool in the policy: it disappears from the agent's `tools/list` — the agent that can't call it doesn't know it exists. Then add per-tool rate limits (e.g. `generate_uuid` unlimited, `create_user` once per 5 seconds) with independent counters per consumer.
4. **Observability.** The Dashboard's *Activity by MCP* screen shows request volume, method breakdown, per-tool calls, keys, latency, and error rates for the traffic just generated. With `opentelemetry-demo` running, the Grafana MCP dashboard shows the same traffic via OpenTelemetry — the pipeline shared with REST and GraphQL APIs.

### Connecting an agent

Once a proxy and key exist, any MCP-capable agent can connect with a standard config block:

```json
"mock-mcp": {
  "type": "http",
  "url": "http://localhost:8080/mock-mcp/mcp",
  "headers": {
    "Authorization": "<key created in the auth chapter>"
  }
}
```

## Networking Notes

Both supporting services join the base `tyk` network, so the Tyk Gateway can reach the mock server as `http://mcp-mock-server:7878` and the Inspector's proxy can reach the Gateway as `http://tyk-gateway:8080`. Ports are also mapped to the host for browser access and local debugging.

When entering the upstream URL in the Dashboard's MCP Proxy wizard, use the **service name** (`http://mcp-mock-server:7878`) rather than `http://localhost:7878` — the Tyk Gateway runs inside Docker and `localhost` there means the Gateway container itself.

## Related Deployments

- **[mcp-token-exchange](../mcp-token-exchange/README.md)** — the advanced MCP auth story: OAuth 2.0 Token Exchange (RFC 8693) for AI agents acting on behalf of users, with Keycloak and a copilot app (Tyk 5.14+ EE). The two deployments compose: `./up.sh mcp-gateway mcp-token-exchange`.
- **[opentelemetry-demo](../opentelemetry-demo/README.md)** — Grafana MCP metrics dashboard and distributed tracing used in the observability chapter.

## Teardown

```shell
./down.sh
```

The base `down.sh` handles all services brought up by `up.sh`.
