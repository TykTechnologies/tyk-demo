// OpenTelemetry tracing for the chat. The chat opens a span per MCP tool call
// and injects the W3C trace context into the JSON-RPC body's params._meta
// (MCP SEP-414) — the channel Tyk reads to join the agent's trace. Spans export
// to an OTLP/HTTP collector best-effort; the chat runs fine when it is down.
package main

import (
	"context"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// initTracer wires a tracer provider exporting to OTEL_EXPORTER_OTLP_ENDPOINT
// (default http://localhost:4318, plaintext) and installs the W3C trace-context
// propagator. Returns a shutdown func to flush spans on exit.
func initTracer(ctx context.Context) (func(context.Context) error, error) {
	exp, err := otlptracehttp.New(ctx, otlptracehttp.WithInsecure())
	if err != nil {
		return nil, err
	}
	res, _ := resource.New(ctx, resource.WithAttributes(
		semconv.ServiceName("acme-support-chat"),
	))
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})
	return tp.Shutdown, nil
}

// injectMetaTraceContext returns the params _meta map carrying the active
// span's W3C trace context, or nil when no span is active. This is the
// MCP-native (SEP-414) propagation channel.
func injectMetaTraceContext(ctx context.Context) map[string]any {
	carrier := propagation.MapCarrier{}
	otel.GetTextMapPropagator().Inject(ctx, carrier)
	tp := carrier["traceparent"]
	if tp == "" {
		return nil
	}
	meta := map[string]any{"traceparent": tp}
	if ts := carrier["tracestate"]; ts != "" {
		meta["tracestate"] = ts
	}
	return meta
}
