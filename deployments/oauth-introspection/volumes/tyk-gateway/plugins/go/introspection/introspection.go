package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/TykTechnologies/tyk/config"
	"github.com/TykTechnologies/tyk/ctx"
	"github.com/TykTechnologies/tyk/log"
	"github.com/TykTechnologies/tyk/storage"
	"github.com/TykTechnologies/tyk/user"
)

var logger = log.Get()

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
}

// getIntrospectionConfig returns the configuration for OAuth introspection
func getIntrospectionConfig() *IntrospectionConfig {
	return &IntrospectionConfig{
		IntrospectionURL: "http://keycloak:8180/realms/tyk/protocol/openid-connect/token/introspect",
		ClientID:         "tyk-introspection-client",
		ClientSecret:     "tyk-introspection-secret",
	}
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
		Timeout: 10 * time.Second,
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to call introspection endpoint: %v", err)
	}
	defer resp.Body.Close()

	// Read the response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read introspection response: %v", err)
	}

	// Check for HTTP errors
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("introspection endpoint returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse the response
	var introspectionResp IntrospectionResponse
	if err := json.Unmarshal(body, &introspectionResp); err != nil {
		return nil, fmt.Errorf("failed to parse introspection response: %v", err)
	}

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

	// Calculate token expiration (convert from Unix timestamp to TTL)
	var expires int64 = 0
	if introspectionResp.Exp > 0 {
		expires = introspectionResp.Exp - time.Now().Unix()
		if expires < 0 {
			expires = 0
		}
	}

	// Create a session state
	sessionState := &user.SessionState{
		OrgID:   requestedAPI.OrgID,
		Alias:   sessionAlias,
		Rate:    1000, // requests per second
		Per:     1,    // per 1 second
		Expires: expires,
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

	// Extract bearer token from Authorization header
	token := extractBearerToken(r)
	if token == "" {
		logger.Info("No bearer token found in Authorization header")
		rw.WriteHeader(http.StatusUnauthorized)
		rw.Write([]byte(`{"error": "missing_token", "error_description": "Bearer token is required"}`))
		return
	}

	logger.Info("Bearer token extracted: ", token[:20], "...")

	// Get introspection configuration
	config := getIntrospectionConfig()

	// Introspect the token
	introspectionResp, err := introspectToken(token, config)
	if err != nil {
		logger.Error("Token introspection failed: ", err)
		rw.WriteHeader(http.StatusInternalServerError)
		rw.Write([]byte(`{"error": "introspection_failed", "error_description": "Failed to introspect token"}`))
		return
	}

	// Check if token is active
	if !introspectionResp.Active {
		logger.Info("Token is not active")
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
