package main

import (
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
	rc := storage.NewRedisController(r.Context())
	// Create a storage object, which will handle Redis operations using "apikey-" key prefix
	store := storage.RedisCluster{KeyPrefix: "apikey-", HashKeys: conf.HashKeys, RedisController: rc}

	go rc.ConnectToRedis(r.Context(), nil, &conf)
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

	// Set auth header
	r.Header.Add("Authorization", realIp)
	logger.Debug("Setting Authorization to ", realIp)

	ipSession := &user.SessionState{
		OrgID: orgId,
		Alias: "ip-session-" + realIp,
		Rate:  2,
		Per:   5,
		AccessRights: map[string]user.AccessDefinition{
			apiId: {
				APIID: apiId,
			},
		},
	}

	jsonKey := fmt.Sprintf(`{"org":"%s","id":"%s","h":"%s"}`, orgId, realIp, config.Global().HashKeyFunction)
	lookupKey := base64.StdEncoding.EncodeToString([]byte(jsonKey))

	j, err := json.Marshal(ipSession)
	if err != nil {
		logger.Error("Could not marshal SessionState.")
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	err = store.SetKey(lookupKey, string(j), 0)
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
