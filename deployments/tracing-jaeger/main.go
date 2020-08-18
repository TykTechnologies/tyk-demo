package main

import (
	"encoding/json"
	"fmt"
	slog "log"
	"net/http"
	"net/http/httputil"

	"github.com/TykTechnologies/tyk/trace"
	"github.com/opentracing/opentracing-go/log"
)

type mainHandler struct {
	h http.Handler
}

const service = "trace-service"

var serviceName = "opentracing-demo"

func (m mainHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	span, req := trace.Root(serviceName, r)
	defer span.Finish()
	m.h.ServeHTTP(w, req)
}

const zipkinConfig = `{
    "reporter": {
        "url": "http://localhost:9411/api/v2/spans"
    }
}`

const sampleConfig = `{
	"serviceName": "trace-app",
	"disabled": false,
	"rpc_metrics": false,
	"tags": null,
	"sampler": {
		"type": "const",
		"param": 1,
		"samplingServerURL": "",
		"maxOperations": 0,
		"samplingRefreshInterval": 0
	},
	"reporter": {
		"queueSize": 0,
		"BufferFlushInterval": 0,
		"logSpans": true,
		"localAgentHostPort": "jaeger:6831",
		"collectorEndpoint": "",
		"user": "",
		"password": ""
	},
	"headers": null,
	"baggage_restrictions": null,
	"throttler": null
}`

type logger struct{}

func (logger) Errorf(format string, args ...interface{}) {
	fmt.Printf("[ERROR] %s\n", fmt.Sprintf(format, args...))
}
func (logger) Info(args ...interface{}) {
	fmt.Printf("[INFO] %s\n", fmt.Sprint(args...))
}

func (logger) Infof(format string, args ...interface{}) {
	fmt.Printf("[INFO] %s\n", fmt.Sprintf(format, args...))
}

var lg = logger{}

func main() {
	port := 6666
	var o map[string]interface{}
	err := json.Unmarshal([]byte(sampleConfig), &o)
	if err != nil {
		slog.Fatal(err)
	}

	trace.SetupTracing("jaeger", o)
	trace.SetLogger(lg)
	defer trace.Close()
	err = trace.AddTracer("", serviceName)
	if err != nil {
		slog.Fatal(err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/echo", echo)
	h := mainHandler{h: mux}
	slog.Println("starting trace service at :", port)
	slog.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", port), h))
}

func serveErr(w http.ResponseWriter, err error) {
	json.NewEncoder(w).Encode(map[string]string{
		"error": err.Error(),
	})
}

func echo(w http.ResponseWriter, r *http.Request) {
	span, _ := trace.Span(r.Context(), "echo handler")
	defer span.Finish()
	span.LogFields(
		log.String("INFO", "step one"),
	)
	span.LogFields(
		log.String("INFO", "step two"),
	)
	span.LogFields(
		log.String("INFO", "step three"),
	)
	b, _ := httputil.DumpRequest(r, true)
	w.Write(b)
}
