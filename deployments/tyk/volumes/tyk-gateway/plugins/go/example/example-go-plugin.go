package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/TykTechnologies/tyk/config"
	"github.com/TykTechnologies/tyk/ctx"
	"github.com/TykTechnologies/tyk/log"
	"github.com/TykTechnologies/tyk/storage"
	"github.com/TykTechnologies/tyk/user"
)

var logger = log.Get()

func Authenticate(rw http.ResponseWriter, r *http.Request) {
	var err error

	if !storage.Connected() {
		logger.Error("Storage not connected")
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	// connect to Redis using the prefix "apikey-"
	store := storage.RedisCluster{KeyPrefix: "apikey-"}

	// get the Authorization header value
	authHeader := r.Header.Get("Authorization")
	logger.Info("Authorization header: ", authHeader)

	requestedAPI := ctx.GetDefinition(r)

	// calculate the key lookup value
	lookupKey := authHeader
	if config.Global().HashKeys {
		logger.Info("Key hashing is enabled using ", config.Global().HashKeyFunction)
		hashedKey := authHeader
		if storage.TokenOrg(authHeader) != requestedAPI.OrgID {
			logger.Info("Using custom key: ", authHeader)
			jsonKey := fmt.Sprintf(`{"org":"%s","id":"%s","h":"%s"}`, requestedAPI.OrgID, authHeader, config.Global().HashKeyFunction)
			logger.Info("Generated JSON key: ", jsonKey)
			hashedKey = base64.StdEncoding.EncodeToString([]byte(jsonKey))
		} else {
			logger.Info("Using hashed key: ", authHeader)
		}

		lookupKey = storage.HashKey(hashedKey)
	} else {
		logger.Info("Key hashing is disabled")
		logger.Info("Using unhashed key: ", authHeader)
	}
	logger.Info("Lookup key: ", lookupKey)

	// check if key exists
	exists, err := store.Exists(lookupKey)
	if err != nil {
		logger.Error("Couldn't check if key exists in Redis: ", err)
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}
	if !exists {
		logger.Info("No session object for key")
		rw.WriteHeader(http.StatusUnauthorized)
		return
	}

	// use hashed value to get session from Redis storage
	sessionJson, err := store.GetKey(lookupKey)
	if err != nil {
		logger.Error("Couldn't get session from Redis: ", err)
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	// convert to session object
	sessionObject := &user.SessionState{}
	err = json.Unmarshal([]byte(sessionJson), &sessionObject)
	if err != nil {
		logger.Error("Couldn't unmarshal session object: ", err)
	}

	// check if access rights exist for the requested API
	isAuthorized := false
	for k := range sessionObject.AccessRights {
		if k == requestedAPI.APIID {
			isAuthorized = true
			logger.Info("Found access rights for ", requestedAPI.Name)
		}
	}
	if !isAuthorized {
		logger.Info("Session does not have access to requested API ", requestedAPI.Name)
		rw.WriteHeader(http.StatusForbidden)
		return
	}

	// set session state using session object
	ctx.SetSession(r, sessionObject, lookupKey, false)
	logger.Info("Session created for request")
}

// AddHelloWorldHeader adds custom "Hello: World" header to the request
func AddHelloWorldHeader(rw http.ResponseWriter, r *http.Request) {
	r.Header.Add("Hello", "World")
}

// called once plugin is loaded, this is where we put all initialization work for plugin
// i.e. setting exported functions, setting up connection pool to storage and etc.
func init() {
	logger.Info("Initialising Example Go Plugin")
}

func main() {}
