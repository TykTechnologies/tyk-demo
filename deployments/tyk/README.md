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

A [Go Plugin](https://tyk.io/docs/plugins/supported-languages/golang/) is implemented for the *Go Plugin API*. It is a basic implementation which (1) adds a header to the request and (2) masks/obfuscates some response data in the analytics log. See the *Middleware - Go* request (API Definitions > Middleware > Middleware - Go) in the Postman collection for an example.

During the bootstrap script, the Go source in `deployments/tyk/volumes/tyk-gateway/plugins/go/example/example-go-plugin.go` is complied into a shared object library file (`deployments/tyk/volumes/tyk-gateway/plugins/go/example/example-go-plugin.so`), which is referenced by the *Go Plugin API*. A special container is used to build the library file, using the same Go version used to build the Gateway.

#### Analytics Plugin

An example [analytics plugin](https://tyk.io/docs/plugins/plugin-types/analytics-plugins/) function can be found in the [example go plugin](deployments/tyk/volumes/tyk-gateway/plugins/go/example/example-go-plugin.go). The function is called called *MaskAnalyticsData*, and it demonstrates analytics plugin functionality by replacing the value of the `origin` field with asterisks. This effect of this can be seen by sending a request to the [Go Plugin API (No Auth)](http://tyk-gateway.localhost:8080/go-plugin-api-no-auth/get) and viewing the corresponding analytics record in the Dashboard, where the `origin` field in the *Response* body data will be `"origin": "****"`.

### WebSockets and Server-Sent Events

These examples use the *Echo Server* API Definition, which is configured to proxy to `echo-server:8080`, a simple echo server container. The echo server echoes back any message it receives, and has special endpoints which enable demonstration of WebSockets and Server-Sent Events.

#### WebSockets

To see a live demonstration, open the [WebSocket Test Page](http://echo-server.localhost:8080/.ws) in a browser. When this page loads, it automatically opens a WebSocket connection with the API Gateway and uses JavaScript to exchange messages. The Gateway proxies the message to the upstream server and returns the response to the web page. One message is sent every second. If all goes well, it will look something like this:

```
[info]  attempting to connect
[info]  connected
[recv]  Request served by 44a2695777f7
[send]  0 = 0x0
[recv]  0 = 0x0
[send]  1 = 0x1
[recv]  1 = 0x1
```

Check the browser's developer tool network information to see the `MessageEvent` objects.

#### Server-Sent Events

To see a live demonstration, open the [SSE Test Page](http://echo-server.localhost:8080/.sse) in a browser (**Note**: If you are using Firefox, the browser will display a download dialog, rather than write the data to the page). When this page loads, it automatically opens a connection with the API Gateway and awaits messages sent via the open connection. The server sends timestamp data every second, which is then displayed on the page. The output should look something like this:

```
event: server
data: 42ca818c2f16
id: 1

event: request
data: HTTP/1.1 GET /.sse
data: 
data: Host: echo-server:8080
... more request headers ...
data: 
id: 2

event: time
data: 2021-10-15T03:32:35Z
id: 3

event: time
data: 2021-10-15T03:32:36Z
id: 4
```
### ngrok 

Using ngrok generates an external IP and hostname which makes the Tyk Gateway publicly accessible from the internet.

This will simulate and external access which will allow Tyk Gatway to find from which location you are making a request and show it in the "Activity by location section"

The ngrok deployment contains a dashboard which records all requests which pass through the ngrok tunnel.

- [ngrok dashboard](http://localhost:4040)

#### Usage

The Ngrok tunnel URL is displayed in the output of the bootstrap script (`./up.sh`). 
The URL will be something that looks like this: `http://11e3-103-252-202-110.ngrok.io`

APIs can be accessed through the tunnel URL using the same paths as they are accessed through the Gateway URL. 
For example, using the example tunnel URL provided above, the Basic Open API can be accessed as follows:

- Gateway URL: http://tyk-gateway.localhost:8080/basic-open-api/get
- External Tunnel URL: http://11e3-103-252-202-110.ngrok.io/basic-open-api/get

Requests sent via the tunnel are recorded and displayed in the [Ngrok dashboard](http://localhost:4040). 
Try sending some requests through the tunnel URL to generate some data, then check the Dashboard to see what has been recorded.

You can also set the external url as custom domain in the api definition.
 
##### Getting the tunnel URL

To get the tunnel URL at any time, run the following:
```
curl localhost:4040/api/tunnels --silent| jq ".tunnels[0].public_url" --raw-output
```

This will display the tunnel URL e.g. `https://<dynamic-ngrok-allocated-ip>.ngrok.io`.

The tunnel IP can also be seen in the [ngrok dashboard](http://localhost:4040).

##### Renewing the Ngrok session

Anonymous ngrok sessions are capped at 2 hours. So after 2 hours you will need to restart the ngrok container to generate a new session and URL:
`./docker-compose-command.sh restart www-ngrok`

Then, to get the new URL use:

```
curl localhost:4040/api/tunnels --silent | jq ".tunnels[0].public_url" --raw-output
```