# OAuth Introspection Demo

This document provides a quick demo of the OAuth introspection plugin functionality.

## Prerequisites

Make sure you have the following deployments running:
```bash
./up.sh keycloak-dcr oauth-introspection
```

## Demo Steps

### 1. Generate a User Token

First, let's generate a token for our test user:

```bash
curl -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=test-client" \
  -d "client_secret=test-client-secret" \
  -d "username=testuser" \
  -d "password=password" \
  -d "grant_type=password" \
  "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token"
```

**Expected Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "token_type": "Bearer",
  "scope": "profile email"
}
```

### 2. Test the API with Valid Token

Use the token from step 1 to call the protected API:

```bash
export TOKEN="YOUR_ACCESS_TOKEN_HERE"

curl -H "Authorization: Bearer $TOKEN" \
  "http://tyk-gateway.localhost:8080/introspection/anything" | jq
```

**Expected Response:**
```json
{
  "headers": {
    "Authorization": "Bearer eyJhbGciOiJSUzI1NiIs...",
    "X-Oauth-Client-Id": "test-client",
    "X-Oauth-Username": "testuser",
    "X-Oauth-Subject": "user-subject-id",
    "X-Oauth-Scope": "profile email"
  },
  "method": "GET",
  "url": "http://httpbin/anything"
}
```

### 3. Test API without Token

Try calling the API without a token:

```bash
curl "http://tyk-gateway.localhost:8080/introspection/anything"
```

**Expected Response:**
```json
{
  "error": "missing_token",
  "error_description": "Bearer token is required"
}
```

### 4. Test API with Invalid Token

Try calling the API with an invalid token:

```bash
curl -H "Authorization: Bearer invalid.token.here" \
  "http://tyk-gateway.localhost:8080/introspection/anything"
```

**Expected Response:**
```json
{
  "error": "invalid_token",
  "error_description": "Token is not active"
}
```

### 5. Direct Token Introspection

You can also test the introspection endpoint directly:

```bash
curl -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "test-client:test-client-secret" \
  -d "token=$TOKEN" \
  "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect"
```

**Expected Response:**
```json
{
  "active": true,
  "client_id": "test-client",
  "username": "testuser",
  "sub": "user-subject-id",
  "exp": 1704067200,
  "iat": 1704066900,
  "scope": "profile email"
}
```

## What's Happening

1. **Token Generation**: Keycloak generates OAuth tokens for users or service accounts
2. **API Request**: Client sends request with Bearer token to Tyk Gateway
3. **Plugin Execution**: Tyk Gateway runs the introspection plugin
4. **Token Validation**: Plugin calls Keycloak's introspection endpoint
5. **Session Creation**: If token is valid, plugin creates a Tyk session
6. **Header Injection**: Plugin adds OAuth metadata to request headers
7. **Request Forwarding**: Request is forwarded to the upstream service

## Plugin Features Demonstrated

✅ **Token Extraction**: Extracts Bearer tokens from Authorization headers
✅ **Token Validation**: Validates tokens against Keycloak's introspection endpoint using the same client as token generation
✅ **Session Management**: Creates Tyk sessions for valid tokens with proper expiration handling
✅ **Metadata Injection**: Adds OAuth client ID, username, subject, and scope as headers
✅ **Error Handling**: Proper HTTP error responses for invalid/missing tokens
✅ **Network Compatibility**: Uses keycloak.localhost for consistent hostname resolution

## Automated Testing

For comprehensive testing, use the provided test script:

```bash
./deployments/oauth-introspection/scripts/test-introspection.sh
```

This will automatically run through all the scenarios above and verify the expected behavior.

## Postman Collection

Import the Postman collection for interactive testing:
- File: `deployments/oauth-introspection/data/tyk_demo_oauth_introspection.postman_collection.json`
- Contains pre-configured requests with test assertions
- Easy token management with environment variables

## Troubleshooting

### Common Issues

1. **Connection Refused**: Make sure Keycloak is running (`./up.sh keycloak-dcr`)
2. **Invalid Token**: Tokens expire after 5 minutes, generate a new one
3. **Plugin Not Found**: Ensure the plugin was built successfully
4. **404 Not Found**: Check that the API is deployed and accessible
5. **Token Introspection Failed**: The plugin uses the same client (`test-client`) for introspection as token generation

### Debug Information

Check the Tyk Gateway logs for plugin debug information:
```bash
docker logs tyk-demo-tyk-gateway-1 -f
```

Look for log messages like:
- "OAuth Introspection Go Plugin initialized"
- "OAuth Introspection plugin started"
- "Token is active for client: test-client"
- "OAuth introspection successful, session created"

## Summary

The OAuth introspection plugin successfully demonstrates:

1. **OAuth2 Token Introspection** with Keycloak using unified client credentials
2. **Seamless Integration** with Tyk Gateway via Go plugin
3. **Session Management** with proper expiration handling
4. **Security** through proper token validation and network configuration
5. **Metadata Injection** for downstream services with OAuth context

This implementation provides a solid foundation for production OAuth authentication workflows with Tyk Gateway.