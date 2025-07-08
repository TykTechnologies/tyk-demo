# OAuth Introspection

## Overview

This deployment sets up Keycloak with the basic configuration needed for OAuth2 token introspection. It creates a realm, clients, and test user to enable token-based authentication testing.

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

## Next Steps

This deployment provides the basic Keycloak setup. Additional components can be added:
- Tyk Go plugin for token introspection
- API definitions that use the introspection
- Additional test scenarios and validation