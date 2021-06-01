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

### Go Plugin

A [Go Plugin](https://tyk.io/docs/plugins/supported-languages/golang/) is implemented for the *Go Plugin API*. It is a basic implementation which adds a header to the request. See the *Middleware - Go* request (API Definitions > Middleware > Middleware - Go) in the Postman collection for an example.

During the bootstrap script, the Go source in `deployments/tyk/volumes/tyk-gateway/plugins/go/example/example-go-plugin.go` is complied into a shared object library file (`deployments/tyk/volumes/tyk-gateway/plugins/go/example/example-go-plugin.so`), which is referenced by the *Go Plugin API*. A special container is used to build the library file, using the same Go version used to build the Gateway.

### WebSockets

WebSocket proxying is demonstrated using the *WebSocket* API Definition. It's configured to proxy to the `ws://echo.websocket.org` server (note: internet access is required for this example), which will echo back any message it receives.

To see a live demonstration, open the [WebSocket Test page](http://localhost:8888/websocket-test.html), which is included in this deployment, in a browser. When this page loads, it automatically opens a WebSocket connection with the API Gateway and uses JavaScript to send a message. The Gateway proxies the message to the upstream server and returns the response to the web page, which is displayed in on the page. If all goes well, it will look something like this:

```
CONNECTED to ws://tyk-gateway.localhost:8080/websocket/

SENT: Hello, world!

RESPONSE: Hello, world!

DISCONNECTED
```

The source code for the WebSocket Test page can be found in `deployments/tyk/volumes/http-server/websocket-test.html`.
