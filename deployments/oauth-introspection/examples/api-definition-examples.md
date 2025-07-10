# OAuth Introspection Plugin - API Definition Examples

This document provides practical examples of how to configure the OAuth introspection plugin for different environments and use cases.

## Table of Contents

1. [Basic Configuration](#basic-configuration)
2. [Development Environment](#development-environment)
3. [Production Environment](#production-environment)
4. [High Availability Setup](#high-availability-setup)
5. [Multi-Provider Configuration](#multi-provider-configuration)
6. [Performance Optimized](#performance-optimized)
7. [Security Hardened](#security-hardened)
8. [Troubleshooting Configuration](#troubleshooting-configuration)

## Basic Configuration

### Minimal Setup

```json
{
  "api_definition": {
    "name": "Basic OAuth API",
    "slug": "basic-oauth",
    "api_id": "basic-oauth-api",
    "org_id": "your-org-id",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://auth.example.com/oauth/introspect",
      "client_id": "your-client-id",
      "client_secret": "your-client-secret"
    },
    "config_data_disabled": false,
    "active": true
  }
}
```

## Development Environment

### Keycloak Development Setup

```json
{
  "api_definition": {
    "name": "Dev OAuth API",
    "slug": "dev-oauth",
    "api_id": "dev-oauth-api",
    "org_id": "dev-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
      "client_id": "test-client",
      "client_secret": "test-client-secret",
      "timeout_seconds": 10,
      "cache_enabled": false,
      "max_retries": 1,
      "retry_delay": 500
    },
    "config_data_disabled": false,
    "proxy": {
      "listen_path": "/dev-api/",
      "target_url": "http://httpbin.org",
      "strip_listen_path": true
    },
    "active": true
  }
}
```

### Development with Auth0

```json
{
  "api_definition": {
    "name": "Dev Auth0 API",
    "slug": "dev-auth0",
    "api_id": "dev-auth0-api",
    "org_id": "dev-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://dev-tenant.auth0.com/oauth/introspect",
      "client_id": "dev-client-id",
      "client_secret": "dev-client-secret",
      "timeout_seconds": 15,
      "cache_enabled": false,
      "max_retries": 2,
      "retry_delay": 1000
    },
    "config_data_disabled": false,
    "active": true
  }
}
```

## Production Environment

### Enterprise Production Setup

```json
{
  "api_definition": {
    "name": "Production OAuth API",
    "slug": "prod-oauth",
    "api_id": "prod-oauth-api",
    "org_id": "prod-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://auth.company.com/oauth/introspect",
      "client_id": "prod-api-gateway",
      "client_secret": "prod-secure-secret",
      "timeout_seconds": 30,
      "cache_enabled": true,
      "cache_ttl": 600,
      "max_retries": 5,
      "retry_delay": 2000
    },
    "config_data_disabled": false,
    "proxy": {
      "listen_path": "/api/v1/",
      "target_url": "https://backend.company.com",
      "strip_listen_path": true
    },
    "global_rate_limit": {
      "rate": 1000,
      "per": 60
    },
    "active": true
  }
}
```

### Production with Okta

```json
{
  "api_definition": {
    "name": "Production Okta API",
    "slug": "prod-okta",
    "api_id": "prod-okta-api",
    "org_id": "prod-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://company.okta.com/oauth2/v1/introspect",
      "client_id": "okta-client-id",
      "client_secret": "okta-client-secret",
      "timeout_seconds": 25,
      "cache_enabled": true,
      "cache_ttl": 300,
      "max_retries": 3,
      "retry_delay": 1500
    },
    "config_data_disabled": false,
    "active": true
  }
}
```

## High Availability Setup

### Multi-Region Configuration

```json
{
  "api_definition": {
    "name": "HA OAuth API",
    "slug": "ha-oauth",
    "api_id": "ha-oauth-api",
    "org_id": "ha-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://auth-primary.company.com/oauth/introspect",
      "client_id": "ha-client-id",
      "client_secret": "ha-client-secret",
      "timeout_seconds": 5,
      "cache_enabled": true,
      "cache_ttl": 300,
      "max_retries": 5,
      "retry_delay": 500
    },
    "config_data_disabled": false,
    "proxy": {
      "listen_path": "/ha-api/",
      "target_url": "https://backend.company.com",
      "strip_listen_path": true
    },
    "global_rate_limit": {
      "rate": 2000,
      "per": 60
    },
    "active": true
  }
}
```

## Performance Optimized

### High-Throughput Configuration

```json
{
  "api_definition": {
    "name": "High Performance OAuth API",
    "slug": "perf-oauth",
    "api_id": "perf-oauth-api",
    "org_id": "perf-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://auth-fast.company.com/oauth/introspect",
      "client_id": "perf-client",
      "client_secret": "perf-secret",
      "timeout_seconds": 3,
      "cache_enabled": true,
      "cache_ttl": 900,
      "max_retries": 2,
      "retry_delay": 200
    },
    "config_data_disabled": false,
    "cache_options": {
      "cache_timeout": 300,
      "enable_cache": true,
      "cache_all_safe_requests": true
    },
    "active": true
  }
}
```

## Security Hardened

### Maximum Security Configuration

```json
{
  "api_definition": {
    "name": "Secure OAuth API",
    "slug": "secure-oauth",
    "api_id": "secure-oauth-api",
    "org_id": "secure-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://auth-secure.company.com/oauth/introspect",
      "client_id": "secure-client",
      "client_secret": "ultra-secure-secret",
      "timeout_seconds": 10,
      "cache_enabled": false,
      "max_retries": 1,
      "retry_delay": 0
    },
    "config_data_disabled": false,
    "enable_ip_whitelisting": true,
    "allowed_ips": ["10.0.0.0/8", "172.16.0.0/12"],
    "strip_auth_data": true,
    "enable_detailed_recording": true,
    "active": true
  }
}
```

## Multi-Provider Configuration

### Different APIs with Different Providers

#### API 1: Keycloak
```json
{
  "api_definition": {
    "name": "Keycloak OAuth API",
    "slug": "keycloak-oauth",
    "api_id": "keycloak-oauth-api",
    "org_id": "multi-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://keycloak.company.com/realms/api/protocol/openid-connect/token/introspect",
      "client_id": "keycloak-api-client",
      "client_secret": "keycloak-secret",
      "timeout_seconds": 15,
      "cache_enabled": true,
      "cache_ttl": 600,
      "max_retries": 3,
      "retry_delay": 1000
    },
    "config_data_disabled": false,
    "proxy": {
      "listen_path": "/keycloak-api/",
      "target_url": "https://backend1.company.com",
      "strip_listen_path": true
    },
    "active": true
  }
}
```

#### API 2: Auth0
```json
{
  "api_definition": {
    "name": "Auth0 OAuth API",
    "slug": "auth0-oauth",
    "api_id": "auth0-oauth-api",
    "org_id": "multi-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://company.auth0.com/oauth/introspect",
      "client_id": "auth0-api-client",
      "client_secret": "auth0-secret",
      "timeout_seconds": 20,
      "cache_enabled": true,
      "cache_ttl": 300,
      "max_retries": 4,
      "retry_delay": 1500
    },
    "config_data_disabled": false,
    "proxy": {
      "listen_path": "/auth0-api/",
      "target_url": "https://backend2.company.com",
      "strip_listen_path": true
    },
    "active": true
  }
}
```

## Troubleshooting Configuration

### Debug Mode Configuration

```json
{
  "api_definition": {
    "name": "Debug OAuth API",
    "slug": "debug-oauth",
    "api_id": "debug-oauth-api",
    "org_id": "debug-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://auth.company.com/oauth/introspect",
      "client_id": "debug-client",
      "client_secret": "debug-secret",
      "timeout_seconds": 60,
      "cache_enabled": false,
      "max_retries": 0,
      "retry_delay": 0
    },
    "config_data_disabled": false,
    "enable_detailed_recording": true,
    "detailed_tracing": true,
    "active": true
  }
}
```

### Fallback Configuration (Config Disabled)

```json
{
  "api_definition": {
    "name": "Fallback OAuth API",
    "slug": "fallback-oauth",
    "api_id": "fallback-oauth-api",
    "org_id": "fallback-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {
      "introspection_url": "https://auth.company.com/oauth/introspect",
      "client_id": "fallback-client",
      "client_secret": "fallback-secret"
    },
    "config_data_disabled": true,
    "active": true
  }
}
```

## Configuration Validation

Before deploying any of these configurations, use the validation tools:

```bash
# Validate configuration
./validate-config.sh -f your-api-definition.json -v

# Run test suite
./test-config-examples.sh
```

## Environment Variables

For sensitive data like client secrets, consider using environment variables:

```json
{
  "config_data": {
    "introspection_url": "https://auth.company.com/oauth/introspect",
    "client_id": "${OAUTH_CLIENT_ID}",
    "client_secret": "${OAUTH_CLIENT_SECRET}"
  }
}
```

## Best Practices

1. **Security**: Never commit client secrets to version control
2. **Performance**: Enable caching in production environments
3. **Reliability**: Configure appropriate retry policies
4. **Monitoring**: Use detailed recording for troubleshooting
5. **Testing**: Always validate configurations before deployment

## Summary

These examples demonstrate the flexibility of the OAuth introspection plugin's configuration system. The `config_data` approach allows you to:

- Configure different OAuth providers per API
- Adjust performance settings per environment
- Implement security policies as needed
- Debug issues with detailed logging
- Maintain consistent configuration across deployments

Each configuration can be validated using the provided tools and customized for your specific requirements.