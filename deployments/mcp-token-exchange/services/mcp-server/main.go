// Generic OpenAPI-driven MCP tool server for the Acme Support Copilot demo.
//
// It reads an OpenAPI 3 spec (MCP_OAS_PATH) and exposes every operation as an
// MCP tool over streamable HTTP (/mcp). Each tool replays the inbound bearer and
// forwards the trace context to the upstream API (through Tyk). For the demo the
// spec is acme-api.oas.json, so lookup_customer / recent_orders / issue_refund
// come entirely from the spec — no hand-wired tools. Auth/scope is enforced by
// the gateway, not here.
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

const (
	serverName    = "acme-mcp-server"
	serverVersion = "1.0.0"
)

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// ---- per-request metadata (so a tool can read the inbound headers) ----------

type requestMeta struct{ Headers map[string]string }

var (
	currentMeta *requestMeta
	metaMu      sync.RWMutex
)

func setMeta(m *requestMeta) { metaMu.Lock(); currentMeta = m; metaMu.Unlock() }
func getMeta() *requestMeta {
	metaMu.RLock()
	defer metaMu.RUnlock()
	if currentMeta == nil {
		return &requestMeta{Headers: map[string]string{}}
	}
	return currentMeta
}

func captureMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := make(map[string]string, len(r.Header))
		for name, vals := range r.Header {
			if len(vals) > 0 {
				h[name] = vals[0]
			}
		}
		setMeta(&requestMeta{Headers: h})
		next.ServeHTTP(w, r)
	})
}

// inboundBearer / forwardTraceHeaders are used by the OAS tool handler.
func inboundBearer() string { return getMeta().Headers["Authorization"] }

func forwardTraceHeaders(req *http.Request) {
	for _, h := range []string{"Traceparent", "Tracestate"} {
		if v := getMeta().Headers[h]; v != "" {
			req.Header.Set(h, v)
		}
	}
}

func main() {
	specPath := env("MCP_OAS_PATH", "acme-api.oas.json")
	cfg := UpstreamConfig{
		BaseURL:      env("UPSTREAM_BASE_URL", "http://localhost:8181"),
		Host:         env("UPSTREAM_HOST", "api.acme.internal"),
		ForwardAuth:  env("FORWARD_AUTH", "true") != "false",
		ForwardTrace: env("FORWARD_TRACE", "true") != "false",
	}

	server := mcp.NewServer(&mcp.Implementation{Name: serverName, Version: serverVersion}, nil)
	tools, err := RegisterFromOAS(server, specPath, cfg)
	if err != nil {
		log.Fatalf("registering tools from %q: %v", specPath, err)
	}
	log.Printf("registered %d tool(s) from %s: %v", len(tools), specPath, tools)

	port := env("PORT", "7878")
	mux := http.NewServeMux()
	mcpHandler := mcp.NewStreamableHTTPHandler(func(*http.Request) *mcp.Server { return server }, nil)
	mux.Handle("/mcp", captureMiddleware(mcpHandler))
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"status":"healthy","version":"%s","tools":%d}`, serverVersion, len(tools))
	})

	srv := &http.Server{Addr: ":" + port, Handler: mux, ReadTimeout: 15 * time.Second, IdleTimeout: 60 * time.Second}
	go func() {
		log.Printf("%s v%s — MCP on http://localhost:%s/mcp  → upstream %s (Host %s)",
			serverName, serverVersion, port, cfg.BaseURL, cfg.Host)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
}
