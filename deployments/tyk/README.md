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

## Features

### Secure Payloads

The deployment is configured to for [secure communication](https://tyk.io/docs/tyk-configuration-reference/securing-system-payloads/) between the Dashboard and Gateway. The Dashboard signs messages sent to the Gateway, which is the Gateway is able to verify.

This is acheived using a public/private key pair. The Gateway has the public key, and the Dashboard has the private key - see the mappings for `public-key.pem` and `private-key.pem` in `docker-compose.yml`. To enable the feature, the `allow_insecure_configs` setting in `tyk.conf` is set to `false`.

### TLS Gateway

The TLS-enabled Gateway uses a self-signed certificate, so make sure to instruct your HTTP client is ignore certificate verification failure.

- [Tyk TLS Gateway](https://tyk-gateway-2.localhost:8081/basic-open-api/get)