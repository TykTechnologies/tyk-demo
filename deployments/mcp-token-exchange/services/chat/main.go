// Acme Support Copilot — a browser chat that is a real MCP client.
//
// A support rep logs in via Keycloak (auth-code + PKCE); the Go backend holds
// the SSO token and calls MCP tools through the Tyk MCP proxy with that bearer.
// Tyk runs the RFC 8693 exchange, so the token the downstream API echoes keeps
// sub=<rep> while its audience and scope are re-pointed at the one action. The
// UI decodes both tokens so the on-behalf-of chain is visible.
package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	_ "embed"

	"github.com/modelcontextprotocol/go-sdk/mcp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
)

//go:embed index.html
var indexHTML []byte

//go:embed guide.html
var guideHTML []byte

//go:embed setup.html
var setupHTML []byte

// ---- configuration (Keycloak in compose + local Tyk) ------------------------
// The authorize URL is browser-facing (localhost-published Keycloak); the token
// URL is what THIS process can reach (the in-network keycloak:8080 alias when
// running in compose). Keycloak's pinned hostname keeps the issuer identical
// on both paths.
var cfg = struct {
	AuthorizeURL string
	TokenURL     string
	ClientID     string
	RedirectURI  string
	Scopes       string
	MCPEndpoint  string
	Listen       string
}{
	AuthorizeURL: env("IDP_AUTHORIZE_URL", "http://localhost:8081/realms/acme/protocol/openid-connect/auth"),
	TokenURL:     env("IDP_TOKEN_URL", "http://localhost:8081/realms/acme/protocol/openid-connect/token"),
	ClientID:     env("CHAT_CLIENT_ID", "acme-support-chat"),
	RedirectURI:  env("CHAT_REDIRECT_URI", "http://localhost:8090/callback"),
	Scopes:       env("CHAT_SCOPES", "openid customers:all"),
	MCPEndpoint:  env("MCP_ENDPOINT", "http://localhost:8181/acme-mcp/mcp"),
	Listen:       env("CHAT_LISTEN", ":8090"),
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// ---- session + pending-login state -----------------------------------------
type session struct {
	AccessToken string
	IDToken     string
	Sub         string
	Name        string
}

type pending struct {
	verifier string
	created  time.Time
}

var (
	mu       sync.Mutex
	sessions = map[string]*session{}
	pendings = map[string]*pending{} // keyed by oauth state
)

func newID() string {
	b := make([]byte, 24)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

// ---- PKCE -------------------------------------------------------------------
func pkce() (verifier, challenge string) {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	verifier = base64.RawURLEncoding.EncodeToString(b)
	sum := sha256.Sum256([]byte(verifier))
	challenge = base64.RawURLEncoding.EncodeToString(sum[:])
	return
}

// ---- JWT decode (display only; signature already verified by the gateway) --
func decodeClaims(token string) map[string]any {
	token = strings.TrimPrefix(token, "Bearer ")
	parts := strings.Split(token, ".")
	if len(parts) < 2 {
		return nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil
	}
	var m map[string]any
	if json.Unmarshal(raw, &m) != nil {
		return nil
	}
	return m
}

// ---- MCP client: inject the rep's bearer via a RoundTripper ----------------
type bearerRT struct {
	base        http.RoundTripper
	bearer      string
	wwwAuthOnce string // captured WWW-Authenticate header from the first 403
}

func (b *bearerRT) RoundTrip(r *http.Request) (*http.Response, error) {
	// The MCP client opens an optional long-lived GET for a server-push stream.
	// The mock server holds it open without flushing headers, so Tyk 504s the
	// idle GET and the client treats that as fatal. Returning 405 (per MCP spec)
	// tells the client the server offers no push stream, so it proceeds with
	// request/response only. POST (tool calls) and DELETE (close) pass through.
	if r.Method == http.MethodGet {
		return &http.Response{
			StatusCode: http.StatusMethodNotAllowed,
			Status:     "405 Method Not Allowed",
			Proto:      "HTTP/1.1", ProtoMajor: 1, ProtoMinor: 1,
			Header:  make(http.Header),
			Body:    io.NopCloser(strings.NewReader("")),
			Request: r,
		}, nil
	}
	r = r.Clone(r.Context())
	r.Header.Set("Authorization", "Bearer "+b.bearer)
	resp, err := b.base.RoundTrip(r)
	if err == nil && resp.StatusCode == http.StatusForbidden && b.wwwAuthOnce == "" {
		b.wwwAuthOnce = resp.Header.Get("Www-Authenticate")
	}
	return resp, err
}

func callTool(ctx context.Context, bearer, tool string, args map[string]any) (*mcp.CallToolResult, string, error) {
	// One span per tool call. Its W3C trace context is injected into the
	// request's params._meta below, so Tyk (and the downstream MCP server) join
	// this trace instead of forking their own.
	// The mcp.tool attribute and error status feed the collector's spanmetrics
	// connector, which derives the per-tool usage/failure/latency metrics behind
	// the "Acme — MCP Usage" Grafana dashboard.
	ctx, span := otel.Tracer("acme-support-chat").Start(ctx, "mcp "+tool,
		trace.WithAttributes(attribute.String("mcp.tool", tool)))
	defer span.End()

	// No client-level Timeout: the streamable transport keeps a long-lived GET
	// open for server-sent events, and an http.Client.Timeout would kill it and
	// fail the whole session. Per-call deadlines come from ctx instead.
	// otelhttp injects the W3C traceparent HEADER on every outbound call, so the
	// gateway's root request span joins this trace (the body _meta below covers
	// the MCP-native channel the downstream server reads).
	rt := &bearerRT{base: otelhttp.NewTransport(http.DefaultTransport), bearer: bearer}
	transport := &mcp.StreamableClientTransport{
		Endpoint:   cfg.MCPEndpoint,
		HTTPClient: &http.Client{Transport: rt},
	}
	client := mcp.NewClient(&mcp.Implementation{Name: "acme-support-chat", Version: "1.0.0"}, nil)
	cs, err := client.Connect(ctx, transport, nil)
	if err != nil {
		span.SetStatus(codes.Error, "mcp connect failed")
		return nil, "", err
	}
	defer cs.Close()

	params := &mcp.CallToolParams{Name: tool, Arguments: args}
	if meta := injectMetaTraceContext(ctx); meta != nil {
		params.Meta = meta // params._meta.traceparent — the MCP-native trace channel
	}
	result, callErr := cs.CallTool(ctx, params)
	if callErr != nil || (result != nil && result.IsError) {
		span.SetStatus(codes.Error, "tool call failed")
	}
	return result, rt.wwwAuthOnce, callErr
}

// ---- HTTP handlers ----------------------------------------------------------
func sessionFor(r *http.Request) *session {
	c, err := r.Cookie("sid")
	if err != nil {
		return nil
	}
	mu.Lock()
	defer mu.Unlock()
	return sessions[c.Value]
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(indexHTML)
}

func handleGuide(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(guideHTML)
}

func handleSetup(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(setupHTML)
}

func handleMe(w http.ResponseWriter, r *http.Request) {
	s := sessionFor(r)
	if s == nil {
		writeJSON(w, map[string]any{"loggedIn": false})
		return
	}
	writeJSON(w, map[string]any{
		"loggedIn": true,
		"sub":      s.Sub,
		"name":     s.Name,
		"ssoToken": decodeClaims(s.AccessToken),
		// raw bearer so the inspector can offer a "paste into jwt.io" box,
		// mirroring upstreamTokenRaw on the exchanged token.
		"ssoTokenRaw": strings.TrimPrefix(s.AccessToken, "Bearer "),
	})
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	verifier, challenge := pkce()
	state := newID()
	mu.Lock()
	pendings[state] = &pending{verifier: verifier, created: time.Now()}
	mu.Unlock()

	q := url.Values{}
	q.Set("response_type", "code")
	q.Set("client_id", cfg.ClientID)
	q.Set("redirect_uri", cfg.RedirectURI)
	q.Set("scope", cfg.Scopes)
	q.Set("state", state)
	q.Set("code_challenge", challenge)
	q.Set("code_challenge_method", "S256")
	// Force Keycloak to re-prompt instead of silently reusing the existing SSO
	// session, so signing out and back in can switch users (e.g. alice -> bob).
	// Set LOGIN_PROMPT="" to disable, or "select_account" for an account picker.
	if p := env("LOGIN_PROMPT", "login"); p != "" {
		q.Set("prompt", p)
	}
	http.Redirect(w, r, cfg.AuthorizeURL+"?"+q.Encode(), http.StatusFound)
}

func handleCallback(w http.ResponseWriter, r *http.Request) {
	if e := r.URL.Query().Get("error"); e != "" {
		http.Error(w, "login error: "+e+" — "+r.URL.Query().Get("error_description"), http.StatusBadRequest)
		return
	}
	state := r.URL.Query().Get("state")
	code := r.URL.Query().Get("code")
	mu.Lock()
	p := pendings[state]
	delete(pendings, state)
	mu.Unlock()
	if p == nil {
		http.Error(w, "unknown or expired login state", http.StatusBadRequest)
		return
	}

	form := url.Values{}
	form.Set("grant_type", "authorization_code")
	form.Set("code", code)
	form.Set("redirect_uri", cfg.RedirectURI)
	form.Set("client_id", cfg.ClientID)
	form.Set("code_verifier", p.verifier)

	resp, err := http.PostForm(cfg.TokenURL, form)
	if err != nil {
		http.Error(w, "token request failed: "+err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()
	var tok struct {
		AccessToken string `json:"access_token"`
		IDToken     string `json:"id_token"`
		Error       string `json:"error"`
		ErrorDesc   string `json:"error_description"`
	}
	json.NewDecoder(resp.Body).Decode(&tok)
	if tok.AccessToken == "" {
		http.Error(w, "no access token: "+tok.Error+" "+tok.ErrorDesc, http.StatusBadGateway)
		return
	}

	s := &session{AccessToken: tok.AccessToken, IDToken: tok.IDToken}
	if c := decodeClaims(tok.AccessToken); c != nil {
		s.Sub, _ = c["sub"].(string)
	}
	if c := decodeClaims(tok.IDToken); c != nil {
		if n, ok := c["name"].(string); ok {
			s.Name = n
		} else if n, ok := c["preferred_username"].(string); ok {
			s.Name = n
		}
	}
	sid := newID()
	mu.Lock()
	sessions[sid] = s
	mu.Unlock()
	http.SetCookie(w, &http.Cookie{Name: "sid", Value: sid, Path: "/", HttpOnly: true})
	http.Redirect(w, r, "/", http.StatusFound)
}

func handleLogout(w http.ResponseWriter, r *http.Request) {
	if c, err := r.Cookie("sid"); err == nil {
		mu.Lock()
		delete(sessions, c.Value)
		mu.Unlock()
	}
	http.SetCookie(w, &http.Cookie{Name: "sid", Value: "", Path: "/", MaxAge: -1})
	writeJSON(w, map[string]any{"ok": true})
}

func handleTool(w http.ResponseWriter, r *http.Request) {
	s := sessionFor(r)
	if s == nil {
		http.Error(w, "not logged in", http.StatusUnauthorized)
		return
	}
	var req struct {
		Tool       string  `json:"tool"`
		CustomerID string  `json:"customer_id"`
		Amount     float64 `json:"amount"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	args := map[string]any{"customer_id": req.CustomerID}
	if req.Tool == "issue_refund" {
		args["amount"] = req.Amount
	}
	if req.Tool == "update_customer" {
		args["email"] = "updated@acme.example"
	}

	ctx, cancel := context.WithTimeout(r.Context(), 35*time.Second)
	defer cancel()
	res, wwwAuth, err := callTool(ctx, s.AccessToken, req.Tool, args)

	out := map[string]any{"tool": req.Tool}
	if err != nil {
		// A scope denial at the MCP proxy comes back as an HTTP 403 the SDK
		// surfaces as "Forbidden" — classify it so the UI shows a clean denial.
		msg := err.Error()
		low := strings.ToLower(msg)
		if strings.Contains(low, "forbidden") || strings.Contains(low, "403") || strings.Contains(low, "insufficient") {
			out["denied"] = true
			out["status"] = 403
			// Surface the WWW-Authenticate header from Tyk's scope-check 403 in
			// the shape the inspector already expects for downstream denials.
			if wwwAuth != "" {
				out["structured"] = map[string]any{
					"responseHeaders": map[string]any{
						"Www-Authenticate": []string{wwwAuth},
					},
				}
			}
		}
		out["error"] = msg
		writeJSON(w, out)
		return
	}
	out["isError"] = res.IsError
	out["structured"] = res.StructuredContent
	// the structured upstream echo carries the forwarded bearer in its headers
	if upstreamTok := extractUpstreamToken(res.StructuredContent); upstreamTok != "" {
		out["upstreamToken"] = decodeClaims(upstreamTok)
		out["upstreamTokenRaw"] = strings.TrimPrefix(upstreamTok, "Bearer ")
	}
	var texts []string
	for _, c := range res.Content {
		if tc, ok := c.(*mcp.TextContent); ok {
			texts = append(texts, tc.Text)
		}
	}
	out["text"] = strings.Join(texts, "\n")
	writeJSON(w, out)
}

// extractUpstreamToken digs the echoed Authorization out of the tool's
// structured output (AcmeCallOutput.upstream is the httpbin /anything echo).
func extractUpstreamToken(structured any) string {
	m, ok := structured.(map[string]any)
	if !ok {
		return ""
	}
	up, ok := m["upstream"].(map[string]any)
	if !ok {
		return ""
	}
	headers, ok := up["headers"].(map[string]any)
	if !ok {
		return ""
	}
	for k, v := range headers {
		if strings.EqualFold(k, "Authorization") {
			if s, ok := v.(string); ok {
				return s
			}
		}
	}
	return ""
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func main() {
	// Tracing: export to the OTLP collector and propagate trace context into
	// MCP params._meta. Best-effort — the chat runs if the collector is down.
	if shutdown, err := initTracer(context.Background()); err != nil {
		log.Printf("otel tracing disabled: %v", err)
	} else {
		defer func() { _ = shutdown(context.Background()) }()
	}

	// Probe mode: ./acme-chat --probe <bearer> [tool] [customer_id]
	// Exercises the real callTool path without a browser login (for verification).
	if len(os.Args) > 2 && os.Args[1] == "--probe" {
		tool := "lookup_customer"
		cust := "C-1024"
		if len(os.Args) > 3 {
			tool = os.Args[3]
		}
		if len(os.Args) > 4 {
			cust = os.Args[4]
		}
		ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
		defer cancel()
		pargs := map[string]any{"customer_id": cust}
		if tool == "issue_refund" {
			pargs["amount"] = 49.99
		}
		res, _, err := callTool(ctx, os.Args[2], tool, pargs)
		if err != nil {
			log.Fatalf("probe error: %v", err)
		}
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(map[string]any{"isError": res.IsError, "structured": res.StructuredContent})
		return
	}

	http.HandleFunc("/", handleIndex)
	http.HandleFunc("/guide", handleGuide)
	http.HandleFunc("/setup", handleSetup)
	http.HandleFunc("/api/me", handleMe)
	http.HandleFunc("/login", handleLogin)
	http.HandleFunc("/callback", handleCallback)
	http.HandleFunc("/logout", handleLogout)
	http.HandleFunc("/api/tool", handleTool)
	log.Printf("Acme Support Copilot on %s — MCP %s", cfg.Listen, cfg.MCPEndpoint)
	log.Fatal(http.ListenAndServe(cfg.Listen, nil))
}
