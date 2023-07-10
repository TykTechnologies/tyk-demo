package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"time"

	"github.com/buger/jsonparser"

	"github.com/TykTechnologies/tyk-pump/analytics"
	"github.com/TykTechnologies/tyk/config"
	"github.com/TykTechnologies/tyk/ctx"
	"github.com/TykTechnologies/tyk/log"
	"github.com/TykTechnologies/tyk/storage"
	"github.com/TykTechnologies/tyk/user"
)

var logger = log.Get()

// Writes data in the http.Request object to the Gateway log
func RequestLogger(rw http.ResponseWriter, r *http.Request) {
	// call ParseForm to populate some of the form-related fields
	r.ParseForm()

	logger.Info("Request logger plugin will now log request data...")
	logger.Info("  Method: ", r.Method)
	logger.Info("  Proto: ", r.Proto)
	logger.Info("  ProtoMajor: ", r.ProtoMajor)
	logger.Info("  ProtoMinor: ", r.ProtoMinor)
	logger.Info("  URL.Host: ", r.URL.Host)
	logger.Info("  URL.Path: ", r.URL.Path)
	logger.Info("  URL.Scheme: ", r.URL.Scheme)
	logger.Info("  URL.Fragment: ", r.URL.Fragment)
	logger.Info("  URL.RawQuery: ", r.URL.RawQuery)
	logger.Info("  URL.Opaque: ", r.URL.Opaque)
	for name, _ := range r.Header {
		logger.Info("  Header.Get(\"", name, "\"): ", r.Header.Get(name))
	}
	logger.Info("  ContentLength: ", r.ContentLength)
	logger.Info("  Host: ", r.Host)
	logger.Info("  RemoteAddr: ", r.RemoteAddr)
	logger.Info("  RequestURI: ", r.RequestURI)
	for name, _ := range r.Form {
		logger.Info("  Form.Get(\"", name, "\"): ", r.Form.Get(name))
	}
	for name, _ := range r.PostForm {
		logger.Info("  PostForm.Get(\"", name, "\"): ", r.PostForm.Get(name))
	}
	body, err := ioutil.ReadAll(r.Body)
	if err == nil {
		sb := string(body)
		logger.Info("  Body - read by ioutil.ReadAll(): ", sb)
	}
}

func Authenticate(rw http.ResponseWriter, r *http.Request) {
	// Get the global config - it's needed in various places
	conf := config.Global()
	// Create a Redis Controller, which will handle the Redis connection for the storage
	rc := storage.NewRedisController(context.Background())
	// Create a storage object, which will handle Redis operations using "apikey-" key prefix
	rs := storage.RedisCluster{KeyPrefix: "apikey-", HashKeys: conf.HashKeys, RedisController: rc}

	go rc.ConnectToRedis(context.Background(), nil, &conf)

	// wait for Redis connection
	for {
		if rc.Connected() {
			logger.Info("Redis Controller connected")
			break
		}
		logger.Warn("Redis Controller not connected yet, waiting...")

		time.Sleep(50 * time.Millisecond)
	}

	if conf.HashKeys {
		logger.Info("Key hashing is enabled using ", conf.HashKeyFunction)
	} else {
		logger.Info("Key hashing is disabled")
	}

	// Get the Authorization header value
	authHeader := r.Header.Get("Authorization")
	logger.Info("Authorization header: ", authHeader)

	requestedAPI := ctx.GetDefinition(r)
	if requestedAPI == nil {
		logger.Error("Could not get API Definition")
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	// Calculate the key lookup value
	lookupKey := authHeader
	if storage.TokenOrg(authHeader) == requestedAPI.OrgID {
		// Standard keys don't any special treatment
		logger.Info("Key is an encoded standard key")
		// Log some useful info
		base64decoded, _ := base64.StdEncoding.DecodeString(authHeader)
		logger.Info("Base64 decoded standard key: ", string(base64decoded))
	} else {
		// Custom keys need to be converted to a JSON key for lookup purposes
		logger.Info("Key is a custom key")
		jsonKey := fmt.Sprintf(`{"org":"%s","id":"%s","h":"%s"}`, requestedAPI.OrgID, authHeader, conf.HashKeyFunction)
		logger.Info("Generated JSON for custom key: ", jsonKey)
		lookupKey = base64.StdEncoding.EncodeToString([]byte(jsonKey))
	}

	// This is the key we will be looking for
	logger.Info("Lookup key: ", lookupKey)

	// Check if key exists
	exists, err := rs.Exists(lookupKey)
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

	// Use key to get session from Redis storage
	sessionJson, err := rs.GetKey(lookupKey)
	if err != nil {
		logger.Error("Couldn't get session from Redis: ", err)
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	// Convert to session object
	sessionObject := &user.SessionState{}
	err = json.Unmarshal([]byte(sessionJson), &sessionObject)
	if err != nil {
		logger.Error("Couldn't unmarshal session object: ", err)
	}

	// Check if session object has access rights for the requested API
	// Note: This authorization functionality is provided as an example, for educational purposes. It isn't actually necessary to do this here, as subsequent middleware modules will perform this test.
	isAuthorized := false
	for k := range sessionObject.AccessRights {
		if k == requestedAPI.APIID {
			isAuthorized = true
			logger.Info("Found access rights for ", requestedAPI.Name)
		}
	}
	if !isAuthorized {
		logger.Info("Session does not have access to requested API: ", requestedAPI.Name)
		rw.WriteHeader(http.StatusForbidden)
		return
	}

	// Set session state using session object
	ctx.SetSession(r, sessionObject, false)
	logger.Info("Session created for request")
}

// AddHelloWorldHeader adds custom "Hello: World" header to the request
func AddHelloWorldHeader(rw http.ResponseWriter, r *http.Request) {
	r.Header.Add("Hello", "World")
}

// Writes a string data to the context, which can then be read later
func WriteDataToContext(rw http.ResponseWriter, r *http.Request) {
	logger.Info("WriteDataToContext is called")

	// copy the request context
	ctx := r.Context()
	// add the data
	ctx = context.WithValue(ctx, "MyContextDataKey", "MyContextData")
	// copy the request object, but with new context
	r2 := r.WithContext(ctx)
	// replace request object with new version
	*r = *r2
}

// Reads data from the context and adds it to the response
func AddContextDataToResponse(rw http.ResponseWriter, res *http.Response, req *http.Request) {
	logger.Info("AddContextDataToResponse is called")

	ctx := req.Context()
	// get the data
	myContextData := ctx.Value("MyContextDataKey")
	// check that it isn't nil
	if myContextData != nil {
		// add it as a response header
		res.Header.Add("Data-From-Context", myContextData.(string))
	}
}

// Applies a mask to analytics data
// This example replaces the value stored for the 'origin' field with asterisks
// Only applies to analytics data record, the response to the client remains unchanged
func MaskAnalyticsData(record *analytics.AnalyticsRecord) {
	logger.Info("MaskAnalyticsData Started")

	d, err := base64.StdEncoding.DecodeString(record.RawResponse)
	if err != nil {
		return
	}

	var mask = []byte("\"****\"")
	const endOfHeaders = "\r\n\r\n"
	paths := [][]string{
		{"origin"},
		{"data", "origin"},
	}
	if i := bytes.Index(d, []byte(endOfHeaders)); i > 0 || (i+4) < len(d) {
		body := d[i+4:]
		jsonparser.EachKey(body, func(idx int, _ []byte, _ jsonparser.ValueType, _ error) {
			body, _ = jsonparser.Set(body, mask, paths[idx]...)
		}, paths...)
		if err == nil {
			record.RawResponse = base64.StdEncoding.EncodeToString(append(d[:i+4], body...))
		}
	}
}

// Called once plugin is loaded, this is where we put all initialization work for plugin
// i.e. setting exported functions, setting up connection pool to storage and etc.
func init() {
	logger.Info("Initialising Example Go Plugin")
}

func main() {}
