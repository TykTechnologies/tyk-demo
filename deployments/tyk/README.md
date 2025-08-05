# Tyk Deployment Guide

A comprehensive guide for standard Tyk deployment with Dashboard, Gateway, Pump, Redis, and MongoDB components.

## Quick Access URLs

- [Tyk Dashboard](http://tyk-dashboard.localhost:3000)
- [Tyk Portal (Classic)](http://tyk-portal.localhost:3000/portal)
- [Tyk Gateway](http://tyk-gateway.localhost:8080/basic-open-api/get)
- [Tyk Gateway 2 (TLS)](https://tyk-gateway-2.localhost:8081/basic-open-api/get)

## Getting Started

### Basic Setup

This deployment serves as the foundation for all other deployments. It's automatically deployed using the `up.sh` script, so no `tyk` argument is needed:

```bash
./up.sh
```

### Usage Guide

The bootstrap process imports sample data demonstrating API and Policy configurations. Sign in to the [Tyk Dashboard](http://tyk-dashboard.localhost:3000) to start exploring.

The terminal output displays all the relevant URLs and credentials.

#### API Testing

Import the [Postman collection](deployments/tyk/tyk_demo_tyk.postman_collection.json) into Postman to access a comprehensive library of API requests showcasing Tyk's features.

#### Scaling Your Deployment

Run the `./scripts/add-gateway.sh` script to create additional Gateway instances. New instances will use the same configuration as the existing `tyk-gateway` container but will be mapped to random ports to avoid conflicts.

### Demo Analytics Data

You can seed 7 days of demo analytics data to help explore Tyk's analytics features. This optional feature:

- Generates realistic API traffic data for the past week
- Populates the Dashboard's analytics sections with meaningful data
- Helps demonstrate analytics features without waiting for real traffic

To enable demo data seeding, use the `--seed` flag when running `up.sh`:

```bash
./up.sh --seed
```

You can combine it with other deployments:

```bash
./up.sh analytics-kibana --seed
```

**Note**: The demo data generation requires the `tyk-pump` source code to be available in the parent directory (`../tyk-pump`). If the source is not available, the deployment will continue without seeding demo data.

## Multi-tenancy

The deployment includes two separate organisational tenants:

- **Tyk Demo**: The main organisation, containing the majority of examples
- **Acme**: An additional organisation, to demonstrate multi-tenant functionality

Each organisation has dedicated user accounts for Dashboard access. Users can only access and manage data within their respective organisation.

## Key Features

### Secure Communications

The deployment implements [secure communication](https://tyk.io/docs/api-management/security-best-practices/#sign-payloads) between Dashboard and Gateway through signed messages.

- **Implementation**: Public/private key pair
- **Configuration**: Gateway holds the public key, Dashboard holds the private key
- **Security Setting**: `allow_insecure_configs` in `tyk.conf` is set to `false`

### TLS-Enabled Gateway

The `tyk-gateway-2` gateway is configured to listen using TLS:

- [Tyk TLS Gateway](https://tyk-gateway-2.localhost:8081/basic-open-api/get)

> **Note:** The gateway uses a self-signed certificate, requiring HTTP clients to ignore certificate verification errors when accessing.

### Role-Based API Portal Catalog

The classic Portal has a [slightly modified API Catalogue template](https://github.com/TykTechnologies/tyk-demo/blob/751b99f6a6798b0cd8e0d96952fa0d99579d1080/deployments/tyk/volumes/tyk-dashboard/catalogue.html#L26). If you publish a API and name it "Internal API", it won't be visible to any developers unless they have the necessary profile attribute.

To try:
1. Add an API Definition named "Internal API"
2. Add a policy for the API definition
3. Add a catalog entry for the API to the classic portal
4. Visit the [catalog page](http://tyk-portal.localhost:3000/portal/apis/), the *Internal API* will not be visible
5. Using the Dashboard, edit the developer portal account `portal-developer@example.org`, adding a custom field `internal` with the value `1`
6. Log into the [developer portal](http://tyk-portal.localhost:3000/portal/) - username `portal-developer@example.org`, password `yrPL6CdeJmSCYv7q`
7. Visit the [catalog page](http://tyk-portal.localhost:3000/portal/apis/) again, the *Internal API* will be visible

### Multi-Organisation User Support

[Multi-Organisation Users](https://tyk.io/docs/api-management/user-management/#manage-tyk-dashboard-users-in-multiple-organizations) can access multiple organisations by:

1. Creating accounts with identical email addresses across organisations
2. Authenticating with the Dashboard to view accessible organisations
3. Selecting an organisation to operate within that context

> **Note**: It's not possible to log into multiple organisations simultaneously.

To test this feature, run the `up.sh` script and log in using the provided **Multi-Organisation User** credentials - username `multi-org-user@example.org`, password `eN6yAZwvXUYk2p9S`.

### Detailed Analytics Logging

[Detailed analytics logging](https://tyk.io/docs/api-management/troubleshooting-debugging/#enabling-detailed-logging) captures full HTTP request and response payloads within analytics data.

This feature can be enabled at three levels:
1. Global (Gateway)
2. API
3. Key

The bootstrap script demonstrates each scenario, with the result analytics viewable in the Log Browser report. Additional examples are available in the Postman collection under *API Definition* > *Detailed Analytics Logging*.

### Middleware Implementations

#### Go Plugin

The *Go Plugin API* implements a [Go Plugin](https://tyk.io/docs/plugins/supported-languages/golang/) that:
1. Adds a header to requests
2. Masks/obfuscates response data in analytics logs

During bootstrap, the Go source at `deployments/tyk/volumes/tyk-gateway/plugins/go/example/example-go-plugin.go` is compiled into a shared object library, referenced by the *Go Plugin API*.

##### Analytics Plugin Example

The `MaskAnalyticsData` function in the example Go plugin demonstrates [analytics plugin](https://tyk.io/docs/plugins/plugin-types/analytics-plugins/) functionality by:
- Updating analytics data before database storage
- Replacing the `origin` field value with asterisks

Test this by sending a request to the [Go Plugin API (No Auth)](http://tyk-gateway.localhost:8080/go-plugin-api-no-auth/get) and viewing the analytics record in the Dashboard.

### WebSockets and Server-Sent Events

These examples use the *Echo Server* API Definition configured to proxy to `echo-server:8080`.

#### WebSockets Demo

Visit the [WebSocket Test Page](http://echo-server.localhost:8080/.ws) to see a live demonstration that:
- Automatically opens a WebSocket connection
- Exchanges messages via the API Gateway
- Sends one message per second

Successful operation produces output similar to:

```
[info]  attempting to connect
[info]  connected
[recv]  Request served by 44a2695777f7
[send]  0 = 0x0
[recv]  0 = 0x0
[send]  1 = 0x1
[recv]  1 = 0x1
```

Check browser developer tools for `MessageEvent` objects in the network information.

#### Server-Sent Events Demo

Visit the [SSE Test Page](http://echo-server.localhost:8080/.sse) to see a live demonstration that:
- Opens a connection with the API Gateway
- Receives timestamp data sent every second

Expected output:

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

### External Access via ngrok

ngrok provides external access to your Tyk Gateway, enabling:
- Public internet accessibility
- Geolocation tracking in the "Activity by location" dashboard
- Request recording through the ngrok dashboard

#### Configuration

**Important**: ngrok requires an auth token. To configure:
1. Create an ngrok account on their website
2. Obtain an auth token (not an API key)
3. Add it to the Tyk Demo `.env` file: `NGROK_AUTHTOKEN=MY-AUTH-TOKEN-123`

#### Access and Monitoring

- [ngrok dashboard](http://localhost:4040)
- The ngrok tunnel URL is displayed in the bootstrap script output

APIs are accessible through both the Gateway URL and tunnel URL:
- Gateway URL: `http://tyk-gateway.localhost:8080/basic-open-api/get`
- External Tunnel URL: `http://<dynamic-id>.ngrok.io/basic-open-api/get`

#### Managing the Tunnel

To retrieve the current tunnel URL:
```bash
curl localhost:4040/api/tunnels --silent | jq ".tunnels[0].public_url" --raw-output
```

To renew the ngrok session (anonymous sessions expire after 2 hours):
```bash
./docker-compose-command.sh restart www-ngrok
```

You can also configure the external URL as a custom domain in the API definition.
