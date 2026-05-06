# AI Studio demo — supporting scripts

Runnable scripts referenced by the **AI Studio three-act demo** ([Confluence draft](https://tyktech.atlassian.net/wiki/spaces/SA/pages/edit-v2/4153638928), source-of-truth in `work/2026-05-05--ai-studio-demo-three-acts/artifacts/script.md` until published).

## `customer-bot.py`

Minimal AI Studio-governed bot used in **Act 2: "Build me a Slack/CS bot with tools."**

- ~70 lines, agent-loop + dynamic MCP tool discovery.
- Two governed endpoints, one App credential:
  - LLM calls   → `http://localhost:9090/llm/call/<llm-slug>/v1/messages` (Anthropic SDK with `auth_token=` for `Authorization: Bearer …`)
  - Tool calls  → `http://localhost:9090/tools/<tool-slug>/mcp` (raw `Authorization: <secret>`, no `Bearer` prefix)
- Operations within each tool are discovered at startup via MCP `tools/list` — the bot does not hard-code which operations `httpbin-api` (or any tool) exposes. Tool slugs themselves still come from env (one bootstrap per App config change).

### Run

```bash
# Prereqs: a Tyk Demo "ai-studio" deployment running, an App with at least one
# tool attached, and the App secret copied from the AI Studio dashboard.

# One-time setup. macOS Homebrew Python rejects system-wide pip installs
# (PEP 668), so use a venv. Created at the tyk-demo root; .gitignored.
cd /path/to/tyk-demo
python3 -m venv .venv-ai-studio-demo
source .venv-ai-studio-demo/bin/activate
pip install anthropic requests

# Every demo run after that:
source .venv-ai-studio-demo/bin/activate
export TYK_APP_SECRET=<paste-app-secret>

python deployments/ai-studio/scripts/customer-bot.py "What headers is the bot using?"

# PII-filter trip (Act 2 step 3 — should be intercepted at the gateway):
python deployments/ai-studio/scripts/customer-bot.py "Look up John Doe, DOB 1980-02-15"
```

### Env overrides

| Var | Default | Purpose |
|---|---|---|
| `TYK_APP_SECRET` | — (required) | App credential from AI Studio |
| `AI_STUDIO_URL`  | `http://localhost:9090` | Local AI Studio proxy |
| `LLM_SLUG`       | `self-hosted-claude-sdk` | LLM vendor slug. **Use the `(SDK)` variant, not `(Chat)`**, in chained AI Studio setups (see operations notes in the demo script). |
| `TOOL_SLUGS`     | `httpbin-api` | Comma-separated. Auto-derived from OpenAPI title — copy the actual slug from Administration → Tools. |
| `MODEL`          | `claude-sonnet-4-5-20250929` | Date-suffixed model id; the bare `claude-sonnet-4-5` alias gets a 404 from Anthropic on `/v1/messages`. |

### What the bot does NOT do

- Discover the App's tool slugs from AI Studio at runtime — there's no App-secret-authenticated endpoint for this today. Slugs come from `TOOL_SLUGS` env.
- Run the agent loop server-side. The agent loop lives here, in the bot. AI Studio governs every hop (filters, audit, rate limits, budget), but does not orchestrate.

A future App-level MCP aggregator (`/apps/self/mcp`) would let the bot discover both slugs and operations from one endpoint. Tracked separately.
