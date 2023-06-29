package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/TykTechnologies/tyk/config"
	"github.com/TykTechnologies/tyk/ctx"
	"github.com/TykTechnologies/tyk/log"
	"github.com/TykTechnologies/tyk/request"
	"github.com/TykTechnologies/tyk/storage"
	"github.com/TykTechnologies/tyk/user"
)

var logger = log.Get()

func IPRateLimiter(rw http.ResponseWriter, r *http.Request) {
	// Get the global config - it's needed in various places
	conf := config.Global()
	// Create a Redis Controller, which will handle the Redis connection for the storage
	rc := storage.NewRedisController(context.Background())
	// Create a storage object, which will handle Redis operations using "apikey-" key prefix
	rs := storage.RedisCluster{KeyPrefix: "apikey-", HashKeys: conf.HashKeys, RedisController: rc}
	// The "test" query param denotes that the request is part of a test
	testKeyId := r.URL.Query().Get("test")
	isTestRequest := testKeyId != ""

	go rc.ConnectToRedis(context.Background(), nil, &conf)
	for i := 0; i < 5; i++ { // max 5 attempts - should only take 2
		if rc.Connected() {
			logger.Info("Redis Controller connected")
			break
		}
		logger.Warn("Redis Controller not connected, will retry")

		time.Sleep(10 * time.Millisecond)
	}

	if !rc.Connected() {
		logger.Error("Could not connect to storage")
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	requestedAPI := ctx.GetDefinition(r)
	if requestedAPI == nil {
		logger.Error("Could not get API Definition")
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	// Get the IP address
	realIp := request.RealIP(r)
	orgId := requestedAPI.OrgID
	apiId := requestedAPI.APIID

	// "sessionAlias" is the identifier for the API key
	sessionAlias := "ip-session-" + realIp

	// For the purpose of this demonstration, test requests have a unique id added to them so that they don't interfere with real requests
	if isTestRequest {
		sessionAlias += "-" + testKeyId
	}

	logger.Info("IP Rate Limit Session Alias: ", sessionAlias)

	// Set auth header
	r.Header.Add("Authorization", sessionAlias)

	ipSession := &user.SessionState{
		OrgID: orgId,
		Alias: sessionAlias,
		Rate:  2,
		Per:   5,
		AccessRights: map[string]user.AccessDefinition{
			apiId: {
				APIID: apiId,
			},
		},
	}

	jsonKey := fmt.Sprintf(`{"org":"%s","id":"%s","h":"%s"}`, orgId, sessionAlias, config.Global().HashKeyFunction)
	lookupKey := base64.StdEncoding.EncodeToString([]byte(jsonKey))

	j, err := json.Marshal(ipSession)
	if err != nil {
		logger.Error("Could not marshal SessionState.")
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	err = rs.SetKey(lookupKey, string(j), 0)
	if err != nil {
		logger.Error("Could not store key: ", err)
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}
}

func init() {
	logger.Info("IP rate limiter GO initialised")
}

func main() {}
