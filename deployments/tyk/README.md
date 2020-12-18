# Standard Tyk Deployment

The standard Tyk deployment, with Dashboard, Gateway, Pump, Redis and MongoDB.

- [Tyk Dashboard](http://tyk-dashboard.localhost:3000)
- [Tyk Portal](http://tyk-portal.localhost:3000/portal)
- [Tyk Gateway](http://tyk-gateway.localhost:8080/basic-open-api/get)
- [Tyk Gateway 2](https://tyk-gateway-2.localhost:8081/basic-open-api/get)

## Setup

This deployment is required by all other deployments. It is automatically deployed by the `up.sh` script, so no parameter is required:

```
./up.sh
```

## Usage

The bootstrap process imports sample data to demonstrate how APIs and Policies can be configured. Log into the [Tyk Dashboard](http://tyk-dashboard.localhost:3000) to start using the product.

### Querying the APIs

Import the `Tyk Demo.postman_collection.json` file into Postman to gain access to a library of API requests which demonstrate the features of Tyk

### Scaling the solution

Run the `scripts/add-gateway.sh` script to create a new Gateway instance. It will behave like the existing `tyk-gateway` container as it will use the same configuration. The new Gateway will be mapped on a random port, to avoid collisions.

### Multi-tenancy

There are two Organisations in the deployment who operate as separate tenants:

- Tyk Demo
- Acme

The Organisations have separate users accounts with which to access the Dashboard. When using the Dashboard, users can only access and manage data which belongs to their Organisation.

## Features

### Secure Payloads

The deployment is configured to for [secure communication](https://tyk.io/docs/tyk-configuration-reference/securing-system-payloads/) between the Dashboard and Gateway. The Dashboard signs messages sent to the Gateway, which is the Gateway is able to verify.

This is acheived using a public/private key pair. The Gateway has the public key, and the Dashboard has the private key - see the mappings for `public-key.pem` and `private-key.pem` in `docker-compose.yml`. To enable the feature, the `allow_insecure_configs` setting in `tyk.conf` is set to `false`.

### TLS Gateway

The TLS-enabled Gateway (`tyk-gateway-2`) uses a self-signed certificate. This requires that your HTTP client ignores certificate verification errors when accessing this Gateway.

- [Tyk TLS Gateway](https://tyk-gateway-2.localhost:8081/basic-open-api/get)

### RBAC API Portal Catalogue

The Dashboard has a slightly modified API Catalogue template.  If you publish a policy and name it "Internal API", it won't be visible to any developers unless they have the correct role.

Try viewing the API Catalogue with a developer, then add the "internal" role to the Developer Profile, and see the outcome with values "0" and "1".

### Multi-Organisation User

[Multi-Organiation Users](https://tyk.io/docs/release-notes/version-2.8/#multi-organisation-users) can access multiple Organisations, unlike normal users, who are limited to a single Organisation.

This is made possible by creating an account in each Organisation that has the same username (email address). When this user authenticates with the Dashboard they are presented with a list of Organisations they can access. Selecting an Organisation will then log them into the Dashboard in that Organisational context - it is not possible to log into multiple Organisations at the same time.

To try this out, run the `up.sh` script then log into the Dashboard using the credentials shown for the **Multi-Organisation User**.

### Detailed Analytics Logging

[Detailed analytics logging](https://tyk.io/docs/analytics-and-reporting/useful-debug-modes/#enabling-detailed-logging) is a feature which records the full HTTP request and response payloads as part of the analytics data.

This feature can be enabled at three levels:

1. Global (Gateway)
2. API
3. Key

When a request/response is processed, if any of the levels is enabled, then the detailed analytics data will be logged.

The bootstrap script sends requests for each scenario, which you can see in the Log Browser report. There are also requests in the Postman collection - see *API Definition* > *Detailed Analytics Logging* for more information.

### Python Middleware

[Python middleware](https://tyk.io/docs/plugins/supported-languages/rich-plugins/python/python/) is implemented for the *Python Middleware API*. It is a basic implementation which adds headers to the request and response, and adds log entries to the Gateway's application log. See the *Middleware - Python* request (API Definition > Middleware > Middleware - Python) in the Postman collection for an example.

During the bootstrap script, the Gateway is used to create a plugin bundle, which it signs with its private key so that it can be validated before the Gateway loads it. The plugin is then copied to an Apache server to make it available to the Gateway at runtime when the *Python Middleware API* is requested.

The source and manifest file for the plugin are available in `deployments/tyk/volumes/tyk-gateway/middleware/python/basic-example`.

### JWT scopes example

This example is using elliptic curve keys.
It also demo the usage of scopes
The scope claim name is `"aud"` and the expected scopes are `"client_id_x-readonly" ` and `"client_id_x-readwrite" `. 
If you have one of these claims then you use the `jwks RO policy readonly` or `jwks RW policy readonly`. 
If you don't have  `"aud"` claim then you use the default policy `jwt no access (default) policy` which has access only to one path `/anything/dummy-path` so you can test it and see for yourself that any other path returns `"Access to this resource has been disallowed"`
If you do have `"aud"` but with another scode you will get `"error": "key not authorized: no matching policy found in scope claim"`
 

#### The ES keys
These are the keys for your convinience. You can use them to create the JWT

##### Private key

./deployments/tyk/data/tyk-dashboard/private-es.pem
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIASNlN+KUOZ1+X/HV8jxghdImvyDOCk8Ncw0ohEGG9/PoAoGCCqGSM49
AwEHoUQDQgAEE1kdQIudWMzfq2uf0qs/a/57jdLl6GQ3Do75mvX98xPm1ewc7bHv
jGOynmFaWtYyS/wAQgSkdbJ3WPTsj6XKIw==
-----END EC PRIVATE KEY-----

##### Public key
./deployments/tyk/data/tyk-dashboard/public-es.pem
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEE1kdQIudWMzfq2uf0qs/a/57jdLl
6GQ3Do75mvX98xPm1ewc7bHvjGOynmFaWtYyS/wAQgSkdbJ3WPTsj6XKIw==
-----END PUBLIC KEY-----

#### Example:

The JWT
`eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYXV0IjoiY2xpZW50X2lkX3gtcmVhZG9ubHkifQ.jfjFViM4i-00sRyUjMSTI33RxD9Qnw9UKE5yXwfTOIgKcBOU8QXl0kBKVgTa1scHGgo-7OnxzXNLOeJ8BtyYGA`

```json
{
  "sub": "1234567890",
  "name": "John Doe",
  "aut": "client_id_x-readonly"
}
```

