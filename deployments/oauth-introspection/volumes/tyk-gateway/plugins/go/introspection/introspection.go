package main

import (
	"net/http"

	"github.com/TykTechnologies/tyk/log"
)

var logger = log.Get()

func HelloWorld(rw http.ResponseWriter, r *http.Request) {
	logger.Info("HELLO, WORLD!")
}

func init() {
	logger.Info("HELLO, WORLD! - init() called")
}

func main() {}
