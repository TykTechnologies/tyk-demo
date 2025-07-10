package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/TykTechnologies/tyk/config"
	"github.com/TykTechnologies/tyk/ctx"
	"github.com/TykTechnologies/tyk/log"
	"github.com/TykTechnologies/tyk/storage"
	"github.com/TykTechnologies/tyk/user"
)

var logger = log.Get()

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// OAuth2 introspection response structure
type IntrospectionResponse struct {
	Active    bool   `json:"active"`
	ClientID  string `json:"client_id,omitempty"`
	Username  string `json:"username,omitempty"`
	Sub       string `json:"sub,omitempty"`
	Exp       int64  `json:"exp,omitempty"`
	Iat       int64  `json:"iat,omitempty"`
	Aud       string `json:"aud,omitempty"`
	Iss       string `json:"iss,omitempty"`
	Scope     string `json:"scope,omitempty"`
	TokenType string `json:"token_type,omitempty"`
}

// Configuration for OAuth introspection
type IntrospectionConfig struct {
	IntrospectionURL string
	ClientID         string
	ClientSecret     string
	TimeoutSeconds   int
	CacheEnabled     bool
	CacheTTL         int
	MaxRetries       int
	RetryDelay       int
}

// getIntrospectionConfig returns the configuration for OAuth introspection
// Now reads from API config_data if available, falls back to defaults
func getIntrospectionConfig(r *http.Request) *IntrospectionConfig {
	// Default configuration
	config := &IntrospectionConfig{
		IntrospectionURL: "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
		ClientID:         "test-client",
		ClientSecret:     "test-client-secret",
		TimeoutSeconds:   10,
		CacheEnabled:     true,
		CacheTTL:         300,
		MaxRetries:       3,
		RetryDelay:       1000,
	}

	// Get API definition from request context
	apiSpec := ctx.GetDefinition(r)
	if apiSpec == nil {
		logger.Warn("Could not get API definition, using default config")
		return config
	}

	// Check if config data is available and not disabled
	if apiSpec.ConfigDataDisabled {
		logger.Info("Config data is disabled, using default config")
		return config
	}

	configData := apiSpec.ConfigData
	if configData == nil {
		logger.Info("No config data found, using default config")
		return config
	}

	logger.Info("Reading configuration from API config_data")

	// Extract configuration values from config_data
	if introspectionURL, ok := configData["introspection_url"].(string); ok && introspectionURL != "" {
		config.IntrospectionURL = introspectionURL
		logger.Infof("Using introspection URL from config: %s", introspectionURL)
	}

	if clientID, ok := configData["client_id"].(string); ok && clientID != "" {
		config.ClientID = clientID
		logger.Infof("Using client ID from config: %s", clientID)
	}

	if clientSecret, ok := configData["client_secret"].(string); ok && clientSecret != "" {
		config.ClientSecret = clientSecret
		logger.Info("Using client secret from config (value hidden for security)")
	}

	if timeoutSeconds, ok := configData["timeout_seconds"].(float64); ok && timeoutSeconds > 0 {
		config.TimeoutSeconds = int(timeoutSeconds)
		logger.Infof("Using timeout from config: %d seconds", config.TimeoutSeconds)
	}

	if cacheEnabled, ok := configData["cache_enabled"].(bool); ok {
		config.CacheEnabled = cacheEnabled
		logger.Infof("Using cache enabled from config: %v", cacheEnabled)
	}

	if cacheTTL, ok := configData["cache_ttl"].(float64); ok && cacheTTL > 0 {
		config.CacheTTL = int(cacheTTL)
		logger.Infof("Using cache TTL from config: %d seconds", config.CacheTTL)
	}

	if maxRetries, ok := configData["max_retries"].(float64); ok && maxRetries >= 0 {
		config.MaxRetries = int(maxRetries)
		logger.Infof("Using max retries from config: %d", config.MaxRetries)
	}

	if retryDelay, ok := configData["retry_delay"].(float64); ok && retryDelay > 0 {
		config.RetryDelay = int(retryDelay)
		logger.Infof("Using retry delay from config: %d ms", config.RetryDelay)
	}

	// Validate configuration
	if err := validateConfig(config); err != nil {
		logger.Errorf("Configuration validation failed: %v", err)
		// Return default config on validation failure
		return &IntrospectionConfig{
			IntrospectionURL: "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
			ClientID:         "test-client",
			ClientSecret:     "test-client-secret",
			TimeoutSeconds:   10,
			CacheEnabled:     true,
			CacheTTL:         300,
			MaxRetries:       3,
			RetryDelay:       1000,
		}
	}

	return config
}

// validateConfig validates the introspection configuration
func validateConfig(config *IntrospectionConfig) error {
	if config.IntrospectionURL == "" {
		return fmt.Errorf("introspection_url cannot be empty")
	}

	if config.ClientID == "" {
		return fmt.Errorf("client_id cannot be empty")
	}

	if config.ClientSecret == "" {
		return fmt.Errorf("client_secret cannot be empty")
	}

	if config.TimeoutSeconds <= 0 {
		return fmt.Errorf("timeout_seconds must be greater than 0")
	}

	if config.TimeoutSeconds > 300 {
		return fmt.Errorf("timeout_seconds cannot exceed 300 seconds")
	}

	if config.CacheTTL <= 0 {
		return fmt.Errorf("cache_ttl must be greater than 0")
	}

	if config.MaxRetries < 0 {
		return fmt.Errorf("max_retries cannot be negative")
	}

	if config.MaxRetries > 10 {
		return fmt.Errorf("max_retries cannot exceed 10")
	}

	if config.RetryDelay <= 0 {
		return fmt.Errorf("retry_delay must be greater than 0")
	}

	return nil
}

// extractBearerToken extracts the bearer token from the Authorization header
func extractBearerToken(r *http.Request) string {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return ""
	}

	// Check for Bearer token format
	if strings.HasPrefix(authHeader, "Bearer ") {
		return strings.TrimPrefix(authHeader, "Bearer ")
	}

	return ""
}

// introspectToken calls the OAuth introspection endpoint to validate the token
func introspectToken(token string, config *IntrospectionConfig) (*IntrospectionResponse, error) {
	var lastErr error

	for attempt := 0; attempt <= config.MaxRetries; attempt++ {
		if attempt > 0 {
			logger.Infof("Retrying introspection request (attempt %d/%d)", attempt+1, config.MaxRetries+1)
			time.Sleep(time.Duration(config.RetryDelay) * time.Millisecond)
		}

		resp, err := performIntrospectionRequest(token, config)
		if err == nil {
			return resp, nil
		}

		lastErr = err
		logger.Warnf("Introspection attempt %d failed: %v", attempt+1, err)
	}

	return nil, fmt.Errorf("introspection failed after %d attempts: %v", config.MaxRetries+1, lastErr)
}

// performIntrospectionRequest performs a single introspection request
func performIntrospectionRequest(token string, config *IntrospectionConfig) (*IntrospectionResponse, error) {
	// Prepare the request data
	data := url.Values{}
	data.Set("token", token)

	// Create the HTTP request
	req, err := http.NewRequest("POST", config.IntrospectionURL, strings.NewReader(data.Encode()))
	if err != nil {
		return nil, fmt.Errorf("failed to create introspection request: %v", err)
	}

	// Set authentication using client credentials
	req.SetBasicAuth(config.ClientID, config.ClientSecret)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	// Make the request
	client := &http.Client{
		Timeout: time.Duration(config.TimeoutSeconds) * time.Second,
	}

	logger.Infof("Making introspection request to: %s", config.IntrospectionURL)
	logger.Infof("Using client ID: %s", config.ClientID)
	logger.Infof("Token being introspected: %s...", token[:min(len(token), 20)])

	resp, err := client.Do(req)
	if err != nil {
		logger.Errorf("HTTP request failed: %v", err)
		return nil, fmt.Errorf("failed to call introspection endpoint: %v", err)
	}
	defer resp.Body.Close()

	// Read the response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		logger.Errorf("Failed to read response body: %v", err)
		return nil, fmt.Errorf("failed to read introspection response: %v", err)
	}

	logger.Infof("Introspection response status: %d", resp.StatusCode)
	logger.Infof("Introspection response body: %s", string(body))

	// Check for HTTP errors
	if resp.StatusCode != http.StatusOK {
		logger.Errorf("Introspection endpoint returned error status %d: %s", resp.StatusCode, string(body))
		return nil, fmt.Errorf("introspection endpoint returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse the response
	var introspectionResp IntrospectionResponse
	if err := json.Unmarshal(body, &introspectionResp); err != nil {
		logger.Errorf("Failed to parse JSON response: %v", err)
		logger.Errorf("Response body was: %s", string(body))
		return nil, fmt.Errorf("failed to parse introspection response: %v", err)
	}

	logger.Infof("Parsed introspection response - Active: %v, ClientID: %s, Username: %s",
		introspectionResp.Active, introspectionResp.ClientID, introspectionResp.Username)

	return &introspectionResp, nil
}

// createSessionFromToken creates a Tyk session from a valid OAuth token
func createSessionFromToken(r *http.Request, token string, introspectionResp *IntrospectionResponse) error {
	// Get the API definition
	requestedAPI := ctx.GetDefinition(r)
	if requestedAPI == nil {
		return fmt.Errorf("could not get API definition")
	}

	// Create a unique session alias based on the token subject or client ID
	sessionAlias := "oauth-session-"
	if introspectionResp.Sub != "" {
		sessionAlias += introspectionResp.Sub
	} else if introspectionResp.ClientID != "" {
		sessionAlias += introspectionResp.ClientID
	} else {
		sessionAlias += "unknown"
	}

	// Use the token expiration timestamp directly (Tyk expects absolute timestamp)
	var expires int64 = 0
	if introspectionResp.Exp > 0 {
		expires = introspectionResp.Exp
		logger.Infof("Token expiration: exp=%d", expires)
		if expires < time.Now().Unix() {
			logger.Warnf("Token has already expired: exp=%d, current=%d", expires, time.Now().Unix())
			expires = 0
		}
	}

	// Create a session state
	sessionState := &user.SessionState{
		OrgID:       requestedAPI.OrgID,
		Alias:       sessionAlias,
		Rate:        1000, // requests per second
		Per:         1,    // per 1 second
		Expires:     expires,
		LastUpdated: strconv.FormatInt(time.Now().Unix(), 10),
		BasicAuthData: user.BasicAuthData{
			Password: token, // Store the original token for reference
		},
		AccessRights: map[string]user.AccessDefinition{
			requestedAPI.APIID: {
				APIID: requestedAPI.APIID,
			},
		},
		MetaData: map[string]interface{}{
			"oauth_client_id": introspectionResp.ClientID,
			"oauth_username":  introspectionResp.Username,
			"oauth_subject":   introspectionResp.Sub,
			"oauth_scope":     introspectionResp.Scope,
			"oauth_audience":  introspectionResp.Aud,
			"oauth_issuer":    introspectionResp.Iss,
		},
	}

	// Set the session in the request context
	ctx.SetSession(r, sessionState, false)

	// Store the session in Redis for caching if needed
	if err := storeSessionInRedis(sessionAlias, sessionState, requestedAPI.OrgID); err != nil {
		logger.Warn("Failed to store session in Redis: ", err)
		// Continue anyway, as we've already set the session in the context
	}

	return nil
}

// storeSessionInRedis stores the session in Redis for caching
func storeSessionInRedis(sessionAlias string, sessionState *user.SessionState, orgID string) error {
	// Get the global config
	conf := config.Global()

	// Create a Redis Controller
	rc := storage.NewRedisController(context.Background())
	rs := storage.RedisCluster{KeyPrefix: "apikey-", HashKeys: conf.HashKeys, RedisController: rc}

	// Connect to Redis
	go rc.ConnectToRedis(context.Background(), nil, &conf)
	for i := 0; i < 10; i++ { // wait for connection
		if rc.Connected() {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}

	if !rc.Connected() {
		return fmt.Errorf("could not connect to Redis")
	}

	// Create the lookup key
	jsonKey := fmt.Sprintf(`{"org":"%s","id":"%s","h":"%s"}`, orgID, sessionAlias, conf.HashKeyFunction)
	lookupKey := base64.StdEncoding.EncodeToString([]byte(jsonKey))

	// Marshal the session state
	sessionJSON, err := json.Marshal(sessionState)
	if err != nil {
		return fmt.Errorf("failed to marshal session state: %v", err)
	}

	// Store in Redis with TTL matching token expiration
	ttl := time.Duration(sessionState.Expires) * time.Second
	if ttl <= 0 {
		ttl = 300 * time.Second // Default 5 minutes
	}

	err = rs.SetKey(lookupKey, string(sessionJSON), int64(ttl.Seconds()))
	if err != nil {
		return fmt.Errorf("failed to store session in Redis: %v", err)
	}

	return nil
}

// OAuthIntrospection is the main function that handles OAuth token introspection
func OAuthIntrospection(rw http.ResponseWriter, r *http.Request) {
	logger.Info("OAuth Introspection plugin started")

	// Get introspection configuration first
	config := getIntrospectionConfig(r)
	logger.Infof("Using configuration: URL=%s, ClientID=%s, Timeout=%ds, Cache=%v, CacheTTL=%ds, MaxRetries=%d, RetryDelay=%dms",
		config.IntrospectionURL, config.ClientID, config.TimeoutSeconds,
		config.CacheEnabled, config.CacheTTL, config.MaxRetries, config.RetryDelay)

	// Log all headers for debugging
	logger.Infof("Request headers: %v", r.Header)

	// Extract bearer token from Authorization header
	token := extractBearerToken(r)
	if token == "" {
		logger.Info("No bearer token found in Authorization header")
		authHeader := r.Header.Get("Authorization")
		logger.Infof("Authorization header value: '%s'", authHeader)
		rw.WriteHeader(http.StatusUnauthorized)
		rw.Write([]byte(`{"error": "missing_token", "error_description": "Bearer token is required"}`))
		return
	}

	logger.Info("Bearer token extracted: ", token[:min(len(token), 20)], "...")

	// Introspect the token
	introspectionResp, err := introspectToken(token, config)
	if err != nil {
		logger.Error("Token introspection failed: ", err)
		rw.WriteHeader(http.StatusInternalServerError)
		rw.Write([]byte(`{"error": "introspection_failed", "error_description": "Failed to introspect token"}`))
		return
	}

	logger.Infof("Introspection response: %+v", introspectionResp)

	// Check if token is active
	if !introspectionResp.Active {
		logger.Infof("Token is not active. Full response: %+v", introspectionResp)
		rw.WriteHeader(http.StatusUnauthorized)
		rw.Write([]byte(`{"error": "invalid_token", "error_description": "Token is not active"}`))
		return
	}

	logger.Info("Token is active for client: ", introspectionResp.ClientID, ", user: ", introspectionResp.Username)

	// Create Tyk session from the valid token
	err = createSessionFromToken(r, token, introspectionResp)
	if err != nil {
		logger.Error("Failed to create session from token: ", err)
		rw.WriteHeader(http.StatusInternalServerError)
		rw.Write([]byte(`{"error": "session_creation_failed", "error_description": "Failed to create session"}`))
		return
	}

	logger.Info("OAuth introspection successful, session created")

	// Add introspection info to request headers for downstream services
	r.Header.Set("X-OAuth-Client-ID", introspectionResp.ClientID)
	r.Header.Set("X-OAuth-Username", introspectionResp.Username)
	r.Header.Set("X-OAuth-Subject", introspectionResp.Sub)
	r.Header.Set("X-OAuth-Scope", introspectionResp.Scope)
}

func init() {
	logger.Info("OAuth Introspection Go Plugin initialized")
}

func main() {}
