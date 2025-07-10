# OAuth Introspection Plugin Configuration System

This README provides a comprehensive guide to the configuration system for the OAuth introspection plugin in Tyk Gateway.

## Overview

The OAuth introspection plugin uses Tyk's `config_data` feature to provide flexible, runtime configuration without requiring code changes or plugin rebuilds. This allows you to:

- Configure different OAuth providers per API
- Set custom timeouts and retry policies
- Enable/disable caching
- Modify behavior dynamically

## Quick Start

### 1. Basic Configuration

Add the following to your API definition's `config_data` section:

```json
{
  "config_data": {
    "introspection_url": "https://your-oauth-provider.com/oauth/introspect",
    "client_id": "your-client-id",
    "client_secret": "your-client-secret"
  },
  "config_data_disabled": false
}
```

### 2. Validate Configuration

Use the provided validator script:

```bash
cd deployments/oauth-introspection/scripts
./validate-config.sh
```

### 3. Test Configuration

Run the test suite:

```bash
./test-config-examples.sh
```

## Configuration Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `introspection_url` | string | OAuth2 introspection endpoint URL |
| `client_id` | string | OAuth client ID for authentication |
| `client_secret` | string | OAuth client secret for authentication |

### Optional Parameters

| Parameter | Type | Default | Description | Range |
|-----------|------|---------|-------------|-------|
| `timeout_seconds` | number | 10 | HTTP timeout for requests | 1-300 |
| `cache_enabled` | boolean | true | Enable token caching | - |
| `cache_ttl` | number | 300 | Cache TTL in seconds | 1-86400 |
| `max_retries` | number | 3 | Maximum retry attempts | 0-10 |
| `retry_delay` | number | 1000 | Delay between retries (ms) | 1-30000 |

## Configuration Examples

### Production Configuration

```json
{
  "config_data": {
    "introspection_url": "https://auth.yourcompany.com/oauth/introspect",
    "client_id": "api-gateway-client",
    "client_secret": "your-production-secret",
    "timeout_seconds": 30,
    "cache_enabled": true,
    "cache_ttl": 600,
    "max_retries": 5,
    "retry_delay": 2000
  }
}
```

### Development Configuration

```json
{
  "config_data": {
    "introspection_url": "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
    "client_id": "test-client",
    "client_secret": "test-client-secret",
    "timeout_seconds": 10,
    "cache_enabled": false,
    "max_retries": 1,
    "retry_delay": 500
  }
}
```

### High-Availability Configuration

```json
{
  "config_data": {
    "introspection_url": "https://auth.yourcompany.com/oauth/introspect",
    "client_id": "ha-api-client",
    "client_secret": "your-ha-secret",
    "timeout_seconds": 5,
    "cache_enabled": true,
    "cache_ttl": 300,
    "max_retries": 5,
    "retry_delay": 500
  }
}
```

## How It Works

### 1. Configuration Loading

The plugin loads configuration in the following order:

1. **API Definition**: Reads from `config_data` section
2. **Validation**: Validates all parameters
3. **Fallback**: Uses defaults for missing values
4. **Runtime**: Configuration is read on each request

### 2. Configuration Priority

```
config_data values → defaults → validation fallback
```

### 3. Dynamic Updates

- Changes to `config_data` take effect immediately
- No gateway restart required
- Configuration is validated on each load

## Validation Rules

### URL Validation
- Must be a valid HTTP/HTTPS URL
- Cannot be empty
- Should be accessible from the gateway

### Authentication Validation
- `client_id` and `client_secret` cannot be empty
- Must be valid OAuth client credentials

### Numeric Validation
- `timeout_seconds`: 1-300 seconds
- `cache_ttl`: 1-86400 seconds (1 day)
- `max_retries`: 0-10 attempts
- `retry_delay`: 1-30000 milliseconds

## Tools and Scripts

### Configuration Validator

```bash
# Validate default API definition
./validate-config.sh

# Validate custom file
./validate-config.sh -f custom-api.json

# Validate only config_data section
./validate-config.sh -c

# Verbose output
./validate-config.sh -v
```

### Test Suite

```bash
# Run all configuration tests
./test-config-examples.sh
```

The test suite includes:
- Valid minimal configuration
- Valid full configuration
- Missing required fields
- Invalid timeout values
- Invalid retry counts
- Invalid URL formats
- Empty string values
- Disabled configuration

## Troubleshooting

### Common Issues

1. **Configuration Not Loading**
   - Check `config_data_disabled` is `false`
   - Verify JSON syntax
   - Review gateway logs

2. **Validation Errors**
   - Check parameter types (string, number, boolean)
   - Verify value ranges
   - Ensure required fields are present

3. **Connection Issues**
   - Verify `introspection_url` is accessible
   - Check client credentials
   - Review network connectivity

### Debug Logging

Enable verbose logging to see configuration details:

```
INFO OAuth Introspection plugin started
INFO Using configuration: URL=https://auth.example.com/oauth/introspect, ClientID=my-client, Timeout=30s, Cache=true, CacheTTL=600s, MaxRetries=5, RetryDelay=2000ms
```

### Error Messages

Common error messages and solutions:

| Error | Solution |
|-------|----------|
| "Required field 'client_id' is missing" | Add `client_id` to config_data |
| "timeout_seconds must be greater than 0" | Set timeout between 1-300 |
| "introspection_url must be a valid HTTP/HTTPS URL" | Use valid URL format |
| "Configuration validation failed" | Review all parameters |

## Security Considerations

### Client Secret Protection
- Never log client secrets in plain text
- Store securely in API definition
- Use environment variables where possible
- Rotate secrets regularly

### Network Security
- Use HTTPS for introspection endpoints
- Validate SSL certificates
- Implement proper firewall rules
- Monitor for unauthorized access

### Configuration Security
- Limit access to API definitions
- Use role-based access control
- Audit configuration changes
- Backup configurations securely

## Best Practices

### Environment Management
- Use different configurations per environment
- Separate client credentials per environment
- Test configurations in staging first
- Document environment-specific settings

### Performance Optimization
- Enable caching in production
- Set appropriate cache TTL
- Configure reasonable timeouts
- Monitor performance metrics

### Reliability
- Configure retry policies
- Set up monitoring and alerting
- Test failover scenarios
- Plan for OAuth provider outages

### Monitoring
- Log configuration changes
- Monitor introspection success rates
- Track response times
- Set up alerts for failures

## Integration Examples

### Keycloak Integration
```json
{
  "config_data": {
    "introspection_url": "https://keycloak.example.com/realms/your-realm/protocol/openid-connect/token/introspect",
    "client_id": "tyk-gateway",
    "client_secret": "your-keycloak-secret"
  }
}
```

### Auth0 Integration
```json
{
  "config_data": {
    "introspection_url": "https://your-domain.auth0.com/oauth/introspect",
    "client_id": "your-auth0-client-id",
    "client_secret": "your-auth0-client-secret"
  }
}
```

### AWS Cognito Integration
```json
{
  "config_data": {
    "introspection_url": "https://cognito-idp.us-west-2.amazonaws.com/us-west-2_XXXXXXXXX/oauth2/introspect",
    "client_id": "your-cognito-client-id",
    "client_secret": "your-cognito-client-secret"
  }
}
```

## Migration from Hardcoded Configuration

If you're migrating from hardcoded configuration:

1. **Identify Current Settings**
   - Document current introspection endpoint
   - Note client credentials
   - Record timeout and retry settings

2. **Create config_data Section**
   - Add configuration to API definition
   - Test with a single API first
   - Validate with the validator script

3. **Update Plugin Code**
   - Remove hardcoded values
   - Ensure plugin reads from config_data
   - Test thoroughly

4. **Deploy and Monitor**
   - Deploy to staging first
   - Monitor logs for issues
   - Roll out to production

## Support and Troubleshooting

### Getting Help
- Check the logs for detailed error messages
- Use the validator script to check configuration
- Review the test suite for examples
- Consult the Tyk documentation

### Common Solutions
- **Config not loading**: Check config_data_disabled flag
- **Validation errors**: Review parameter types and ranges
- **Connection issues**: Verify URL and credentials
- **Performance issues**: Adjust timeout and retry settings

### Additional Resources
- [Tyk Gateway Documentation](https://tyk.io/docs/)
- [OAuth2 Token Introspection RFC](https://tools.ietf.org/html/rfc7662)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Auth0 Documentation](https://auth0.com/docs)

---

This configuration system provides a flexible, secure, and maintainable way to configure OAuth introspection for your APIs. The combination of validation, testing, and documentation ensures reliable operation in production environments.