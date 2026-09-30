# Upgrading the vendored MCP Inspector SPA

The bundle in this directory (`index.html` + `assets/` + `mcp.svg`) is the
**built** MCP Inspector single-page app, vendored from npm and served (iframed)
on the docs page of MCP-typed products. It is a third-party static bundle: do not
hand-edit these files.

## Why it's vendored

The portal ships as a self-contained `default.zip` and is frequently run
on-prem / air-gapped. Vendoring keeps the Inspector same-origin (no CSP/CORS or
mixed-content issues), version-pinned, and available without a network round
trip to a CDN.

## Pinned version

The committed bundle is built from the **v1 client** (1.0.1). There is no
`package.json` and no build target in this repo: the bundle is vendored as
build output and updated by hand, so nothing in a normal build clones or
executes third-party sources.

We pin the **v1 client** because it reads the proxy address from
`MCP_PROXY_FULL_ADDRESS` (localStorage `inspectorConfig_v1` + query param) — the
contract the embedded Go proxy (`pkg/mcpp`, `app/mcpp`) already speaks.

> Note: v1 is on npm's `v1-latest` tag (security fixes only). v2
> (`@modelcontextprotocol/inspector`) dropped `MCP_PROXY_FULL_ADDRESS` in favour
> of a different `serverUrl` protocol and is **not** a drop-in replacement — it
> requires reworking the Go proxy's client-address injection. Track that as a
> separate migration, not a version bump here.

## Upgrade checklist (within v1)

1. Build the pinned client outside this repo (a throwaway checkout or `npm pack`
   of the v1 tag), so no build step here fetches or runs third-party code.
2. Copy the resulting `dist/` — `index.html`, the hashed `assets/`, and
   `mcp.svg` — over this directory, replacing its contents. Only built browser
   output belongs here: no sources, lockfiles, or dev dependencies.
3. Verify the SPA entry point (`index.html`) still exists and that the
   Inspector still reads its config from the `inspectorConfig_v1` localStorage
   key + the `MCP_PROXY_FULL_ADDRESS` / `serverUrl` / `MCP_PROXY_AUTH_TOKEN`
   values (the proxy's `InstancesHandler` seeds these — see
   `pkg/mcpp/proxy/instances.go`). If the new build changes those keys, update
   the seeding there.
4. Load an MCP product's docs page locally and confirm the embedded Inspector
   (`/portal/catalogue-products/{product-name}/{api}/mcpp/inspector`) connects to
   the portal-origin proxy (not `localhost:6277`).
5. Regenerate the theme bundle:

       make compress-default-theme

6. Commit the updated assets and `default.zip` together.
