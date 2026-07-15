# MCP Token Exchange (Acme Support Copilot)

A complete demo of **OAuth 2.0 Token Exchange (RFC 8693)** for **AI agents / MCP**, fronted by Tyk and backed by a Keycloak that provisions itself on startup.

An AI support copilot calls real company APIs **on behalf of** a signed-in support rep. The Tyk MCP proxy swaps the rep's login token for an audience-scoped token that **keeps the rep's identity** (`sub`) while narrowing the `scope` to exactly the one action the tool needs — and the downstream API enforces that narrowed scope (read vs refund). This is the RFC 8693 **impersonation** flow: no actor token, no `act` claim; the exchanged token's `azp` records the gateway's client as the caller.

## Prerequisites

- Docker with Docker Compose (4GB+ RAM allocated) and the `jq` command-line utility — the standard Tyk Demo requirements.
- **An enterprise-scoped Tyk licence.** Token exchange is an enterprise feature, so the EE gateway image is required — `up.sh` selects it automatically based on your licence, and this deployment fails fast with an error if the licence isn't enterprise-scoped.
- No Tyk version setup needed: this deployment's `pre.sh` automatically sets the Gateway and Dashboard images to `v5.14.0-rc6` (update once 5.14.0 is GA) and enables OpenTelemetry, pointed at the deployment's own collector.

## Getting started

All commands run from the repo root.

**1. Add the hostname entries** (needed even if you've set up Tyk Demo before — this deployment adds `acme-keycloak`, which your browser needs to reach the IdP with the same issuer URL the containers use):

```bash
sudo ./scripts/update-hosts.sh
```

**2. Add your licence** (skip if your `.env` already has an enterprise-scoped `DASHBOARD_LICENCE`):

```bash
./scripts/update-env.sh DASHBOARD_LICENCE YOUR_LICENCE_KEY
```

**3. Bring the deployment up** (base Tyk deployment included automatically):

```bash
./up.sh mcp-token-exchange
```

On first run the chat app and MCP server are built from source (Go, in Docker) — allow a couple of minutes on top of the usual base-deployment bootstrap. Wait for "Tyk Demo initialisation process completed"; the deployment details below are printed at that point.

**4. Open the demo:** go to http://localhost:8095, sign in as **alice** / `Acme-Demo-2026!`, and run a tool (see [The flow](#the-flow) below).

To stop and remove everything:

```bash
./down.sh
```

To resume a stopped deployment, include the deployment name (this keeps the OpenTelemetry environment variables set — see Troubleshooting):

```bash
./up.sh mcp-token-exchange
```

## Services

Once bootstrapped, these are the places to go:

| Service | Location | Notes |
|---|---|---|
| Tyk Dashboard | http://tyk-dashboard.localhost:3000 | `admin-user@example.org` / `3LEsHO1jv1dt9Xgf` (also printed by `./up.sh`) |
| Copilot chat | http://localhost:8095 | Sign in via Keycloak |
| In-app guides | http://localhost:8095/guide and `/setup` | Plain-English and technical explainers |
| MCP proxy | http://tyk-gateway.localhost:8080/acme-mcp/mcp | The Tyk API that runs the exchange |
| Keycloak admin | http://acme-keycloak:8280 | admin / admin |
| Grafana | http://localhost:3021 | Traces, metrics, and logs (anonymous access) |
| — MCP Usage dashboard | http://localhost:3021/d/acme-mcp-usage | Tool/MCP usage and failures |
| — SLO dashboard | http://localhost:3021/d/YjXeVVZ4k | Standard Tyk SLOs |

### Demo users

Both users sign in with password `Acme-Demo-2026!`:

- **alice** — read-only entitlements: *Look up customer* and *Recent orders* succeed; *Update customer* and *Issue refund* are blocked with an `insufficient_scope` 403, visible in the chat's Delegation inspector.
- **bob** — can also update and refund.

### The flow

1. Open http://localhost:8095 and sign in as alice.
2. Run a tool and watch the **Delegation inspector** decode the SSO token vs the exchanged token: same `sub`, `aud` re-pointed to `api.acme.internal`, `azp` now `tyk-mcp-gateway`, `scope` narrowed from `customers:all` to the one action.
3. Sign out, sign in as bob, and issue a refund — it now succeeds.
4. In **Grafana → Explore → Tempo**, open the request traces; gateway logs are in Loki (`{service_name="tyk-gateway"}`) and the standard Tyk analytics metrics feed the *SLOs for APIs managed by Tyk* dashboard.

> **Note on observability scope:** token exchange ships in 5.14.0; the gateway-native exchange/MCP observability (the exchange OTel span, and the `tyk_mcp_call_*` / `tyk_oauth2_exchange_*` metrics) follows in **5.15.0**. Everything Grafana carries here works on 5.14:
>
> - ***Acme — MCP Usage*** (http://localhost:3021/d/acme-mcp-usage) — most used tools, per-tool call/failure rates and p95 latency (with a tool dropdown), most used MCPs, outcomes and failures by HTTP status. Tool panels are derived from the chat's per-tool-call spans via the collector's spanmetrics connector; status panels come from the pump's `tyk_http_requests_total`.
> - ***SLOs for APIs managed by Tyk*** (http://localhost:3021/d/YjXeVVZ4k) — the standard Tyk SLO dashboard.
>
> Traces (Tempo) and logs (Loki) also work on 5.14. Once on 5.15, the gateway-native metrics can power additional dashboards (the original demo's `mcp-gateway` dashboard lives in the [acme-support-copilot-keycloak-demo](https://github.com/TykTechnologies/acme-support-copilot-keycloak-demo) repo).

## What gets deployed

- **acme-keycloak** — Keycloak 26 with the `acme` realm auto-imported (clients, scopes, protocol mappers, users). The realm enables standard token exchange on the `tyk-mcp-gateway` client.
- **acme-chat** — the copilot web app (embeds the `/guide` and `/setup` explainer pages).
- **acme-mcp-server** — a generic OpenAPI→MCP tool server: it reads the acme-api OAS spec and exposes one MCP tool per operation, replaying the inbound bearer and trace context upstream.
- **acme-otel-collector / acme-tempo / acme-loki / acme-prometheus / acme-grafana / acme-promtail** — the observability pipeline. Only Grafana is published to the host; everything else is internal to the `tyk` network.
- **acme-pump** — a second Tyk pump exposing the standard analytics metrics (`tyk_http_requests_total`, `tyk_http_latency`) to Prometheus, so Grafana also carries the standard *SLOs for APIs managed by Tyk* dashboard alongside the two MCP dashboards.

The bootstrap script publishes two APIs to the Dashboard and binds them to a policy (JWT auth requires one):

- **acme-mcp-proxy** — the MCP gateway API. Listens on `/acme-mcp/`, validates the Keycloak JWT, runs a per-tool scope check against the user's `entitlements` claim, and performs the RFC 8693 exchange (with caching) before proxying to the MCP server.
- **acme-api** — the resource API, matched by the custom domain `api.acme.internal` (no hosts entry needed — the MCP server sends it as an explicit `Host` header). Validates the exchanged token and enforces the narrowed `scope` per operation. Upstream is the base deployment's httpbin.

## Testing

The Postman collection replicates the exchange headlessly: it mints alice's SSO token (password grant), performs the same RFC 8693 exchange the gateway performs, asserts the claim transformation (`sub` preserved, `aud` re-pointed, `scope` narrowed), then verifies the gateway allows a read with the exchanged token and rejects a refund with 403.

```bash
./scripts/test.sh
```

## Troubleshooting

- **404 on `/acme-mcp/mcp` and `api.acme.internal` right after bootstrap** — the base bootstrap restarts the Dashboard, and if the gateway's reload cycle fires during that window it can wedge (observed on `v5.14.0-rc6`: reloads queue but never apply, `reload: initiating` with no `reload: cycle completed` in the gateway log). Restart the gateway to clear it: `docker restart tyk-demo-tyk-gateway-1`.
- **`403 Access disallowed` on every call** — the policy wasn't bound to the APIs; re-run the bootstrap or check `logs/bootstrap.log`.
- **Exchange fails with `Client is not within the token audience`** — the realm import didn't apply (it only runs against an empty database). Recreate the Keycloak container: `docker compose -p tyk-demo rm -sf acme-keycloak && ./up.sh mcp-token-exchange`.
- **Login loops back as the same user** — the chat forces the Keycloak login prompt (`LOGIN_PROMPT=login`) so you can switch alice↔bob; a private window also works.
- **No traces in Grafana** — resuming with a bare `./up.sh` resets the OpenTelemetry Docker environment variables (they are argument-driven); include the deployment name when resuming: `./up.sh mcp-token-exchange`.
- **Refund unexpectedly allowed/denied** — check the user's `entitlements` attribute in the Keycloak admin console (Users → alice → Attributes).
