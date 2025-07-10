# OAuth Introspection Plugin Configuration

This document describes the configuration system for the OAuth introspection plugin, which uses Tyk's `config_data` feature to make the plugin highly configurable without requiring code changes.

## Overview

The OAuth introspection plugin supports dynamic configuration through the API definition's `config_data` section. This allows you to:

- Configure different OAuth providers per API
- Set custom timeouts and retry policies
- Enable/disable caching
- Modify behavior without rebuilding the plugin

## Configuration Structure

The plugin reads configuration from the API definition's `config_data` section. Here's the complete configuration structure:

```json
{
  "config_data": {
    "introspection_url": "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
    "client_id": "test-client",
    "client_secret": "test-client-secret",
    "timeout_seconds": 10,
    "cache_enabled": true,
    "cache_ttl": 300,
    "max_retries": 3,
    "retry_delay": 1000
  },
  "config_data_disabled": false
}
```

## Configuration Options

### Required Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `introspection_url` | string | OAuth2 introspection endpoint URL | `"http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect"` |
| `client_id` | string | OAuth client ID for authentication | `"test-client"` |
| `client_secret` | string | OAuth client secret for authentication | `"test-client-secret"` |

### Optional Parameters

| Parameter | Type | Default | Description | Validation |
|-----------|------|---------|-------------|------------|
| `timeout_seconds` | number | `10` | HTTP timeout for introspection requests | 1-300 seconds |
| `cache_enabled` | boolean | `true` | Enable/disable token caching | - |
| `cache_ttl` | number | `300` | Cache TTL in seconds | > 0 |
| `max_retries` | number | `3` | Maximum retry attempts | 0-10 |
| `retry_delay` | number | `1000` | Delay between retries in milliseconds | > 0 |

## Configuration Priority

The plugin uses a fallback system with the following priority:

1. **config_data values** - Values from the API definition's `config_data` section
2. **Default values** - Built-in defaults if config_data is unavailable
3. **Validation fallback** - Complete default configuration if validation fails

## Configuration Validation

The plugin validates all configuration parameters:

### URL Validation
- `introspection_url` must be a non-empty string
- Must be a valid HTTP/HTTPS URL

### Authentication Validation
- `client_id` must be a non-empty string
- `client_secret` must be a non-empty string

### Timeout Validation
- `timeout_seconds` must be between 1 and 300 seconds
- Values outside this range will cause validation to fail

### Cache Validation
- `cache_ttl` must be greater than 0
- Negative values will cause validation to fail

### Retry Validation
- `max_retries` must be between 0 and 10
- `retry_delay` must be greater than 0

## Configuration Examples

### Basic Configuration
```json
{
  "config_data": {
    "introspection_url": "https://auth.example.com/oauth/introspect",
    "client_id": "my-api-client",
    "client_secret": "my-secret"
  }
}
```

### Advanced Configuration
```json
{
  "config_data": {
    "introspection_url": "https://auth.example.com/oauth/introspect",
    "client_id": "my-api-client",
    "client_secret": "my-secret",
    "timeout_seconds": 30,
    "cache_enabled": true,
    "cache_ttl": 600,
    "max_retries": 5,
    "retry_delay": 2000
  }
}
```

### Disable Caching
```json
{
  "config_data": {
    "introspection_url": "https://auth.example.com/oauth/introspect",
    "client_id": "my-api-client",
    "client_secret": "my-secret",
    "cache_enabled": false
  }
}
```

### High-Availability Configuration
```json
{
  "config_data": {
    "introspection_url": "https://auth.example.com/oauth/introspect",
    "client_id": "my-api-client",
    "client_secret": "my-secret",
    "timeout_seconds": 5,
    "max_retries": 5,
    "retry_delay": 500
  }
}
```

## Runtime Behavior

### Configuration Loading
- Configuration is loaded on each request
- Changes to `config_data` take effect immediately
- No gateway restart required

### Fallback Behavior
- If `config_data_disabled` is `true`, uses built-in defaults
- If any parameter is invalid, logs warning and uses default
- If validation fails completely, uses full default configuration

### Logging
The plugin logs configuration details:
```
INFO Reading configuration from API config_data
INFO Using introspection URL from config: https://auth.example.com/oauth/introspect
INFO Using client ID from config: my-api-client
INFO Using client secret from config (value hidden for security)
INFO Using timeout from config: 30 seconds
INFO Using cache enabled from config: true
INFO Using cache TTL from config: 600 seconds
INFO Using max retries from config: 5
INFO Using retry delay from config: 2000 ms
```

## Security Considerations

### Client Secret Handling
- Client secrets are never logged in plain text
- Stored securely in the API definition
- Transmitted only to the introspection endpoint

### Configuration Validation
- Invalid configurations trigger automatic fallback
- Prevents service disruption from bad configuration
- Logs errors for troubleshooting

## Troubleshooting

### Common Issues

1. **Configuration Not Loading**
   - Check that `config_data_disabled` is `false`
   - Verify JSON syntax in `config_data`
   - Check gateway logs for validation errors

2. **Invalid Configuration**
   - Review validation rules above
   - Check for typos in parameter names
   - Ensure values are correct types (string, number, boolean)

3. **Connection Issues**
   - Verify `introspection_url` is accessible
   - Check network connectivity
   - Validate `client_id` and `client_secret`

### Debug Logging
Enable debug logging to see detailed configuration loading:
```
INFO OAuth Introspection plugin started
INFO Using configuration: URL=https://auth.example.com/oauth/introspect, ClientID=my-api-client, Timeout=30s, Cache=true, CacheTTL=600s, MaxRetries=5, RetryDelay=2000ms
```

## Migration Guide

### From Hardcoded Configuration
1. Add `config_data` section to your API definition
2. Move hardcoded values to `config_data`
3. Test configuration with a single API
4. Roll out to additional APIs

### Updating Existing Configuration
1. Update `config_data` in API definition
2. Save the API definition
3. Configuration takes effect immediately
4. Monitor logs for any validation issues

## Best Practices

1. **Use Environment-Specific Configuration**
   - Different configs for dev/staging/prod
   - Separate client credentials per environment

2. **Monitor Configuration Changes**
   - Log