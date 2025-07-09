# OAuth Introspection

## Overview

This deployment sets up Keycloak with the basic configuration needed for OAuth2 token introspection and includes a Go plugin that demonstrates OAuth introspection functionality with Tyk Gateway. It creates a realm, clients, and test user to enable token-based authentication testing.

## Dependencies

This deployment requires the following deployments to be running:
- `tyk` - Tyk Gateway and Dashboard
- `keycloak-dcr` - Keycloak Identity Provider

## Setup

Run the deployment with its dependencies:

```bash
./up.sh keycloak-dcr oauth-introspection
```

The bootstrap process will:
1. Create a Keycloak realm called "tyk"
2. Set up an introspection client for the gateway
3. Create a test client for generating tokens
4. Create a test user for authentication
5. Build and deploy the OAuth introspection Go plugin
6. Create the introspection API with plugin authentication enabled

## What Gets Created

### Keycloak Realm: `tyk`
- **Access Token Lifespan**: 300 seconds (5 minutes)
- **Enabled**: true

### Introspection Client: `tyk-introspection-client`
- **Purpose**: For Tyk Gateway to introspect tokens
- **Secret**: `tyk-introspection-secret`
- **Type**: Service account only
- **Flows**: Service account enabled, others disabled

### Test Client: `test-client`
- **Purpose**: For generating test tokens
- **Secret**: `test-client-secret`
- **Type**: Confidential client
- **Flows**: Direct access grants, service account, standard flow

### Test User: `testuser`
- **Password**: `password`
- **Email**: `testuser@example.com`
- **Status**: Enabled

## Testing Token Generation

After deployment, you can test token generation:

### Generate User Token
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

### Generate Service Account Token
```bash
curl -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=test-client" \
  -d "client_secret=test-client-secret" \
  -d "grant_type=client_credentials" \
  "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token"
```

### Test Token Introspection
```bash
# Replace YOUR_TOKEN with an actual token from above
curl -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "tyk-introspection-client:tyk-introspection-secret" \
  -d "token=YOUR_TOKEN" \
  "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect"
```

## Access Information

- **Keycloak Admin Console**: http://keycloak.localhost:8180
- **Admin Credentials**: admin/admin
- **Realm**: tyk
- **Test User**: testuser/password
- **Introspection API**: http://tyk-gateway.localhost:8080/introspection/

## OAuth Introspection Plugin

The deployment includes a Go plugin (`introspection.go`) that demonstrates OAuth2 token introspection:

### Plugin Functionality
- Extracts Bearer tokens from the Authorization header
- Validates tokens using Keycloak's introspection endpoint
- Creates Tyk sessions for valid tokens
- Adds OAuth metadata to request headers for downstream services

### Plugin Features
- **Token Validation**: Calls Keycloak's introspection endpoint to validate tokens
- **Session Management**: Creates and caches Tyk sessions for valid tokens
- **Metadata Injection**: Adds OAuth client ID, username, subject, and scope as request headers
- **Error Handling**: Proper error responses for invalid/missing tokens

### Request Headers Added
- `X-OAuth-Client-ID`: OAuth client identifier
- `X-OAuth-Username`: Username (for user tokens)
- `X-OAuth-Subject`: Token subject
- `X-OAuth-Scope`: Token scope

## Testing the Plugin

Use the provided test script to demonstrate the functionality:

```bash
./deployments/oauth-introspection/scripts/test-introspection.sh
```

The test script will:
1. Generate user and service account tokens
2. Test API access with valid tokens
3. Test API rejection of invalid/missing tokens
4. Show OAuth metadata injection

### Manual Testing

1. **Generate a token:**
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

2. **Test the API with the token:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://tyk-gateway.localhost:8080/introspection/anything"
```

3. **Test without token (should get 401):**
```bash
curl "http://tyk-gateway.localhost:8080/introspection/anything"
```

## Plugin Configuration

The plugin is configured in the API definition with:
- **Authentication Type**: Go Plugin Auth (`use_go_plugin_auth: true`)
- **Middleware**: `auth_check` middleware using `OAuthIntrospection`