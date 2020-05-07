## Standard Tyk Deployment

The standard Tyk deployment, with Dashboard, Gateway, Pump, Redis and MongoDB.

- [Tyk Dashboard](http://localhost:3000)
- [Tyk Portal](http://localhost:3000/portal)
- [Tyk Gateway](http://localhost:8080/basic-open-api/get)

This deployment is required by all feature deployments.

### Scaling the solution

Run the `scripts/add-gateway.sh` script to create a new Gateway instance. It will behave like the existing `tyk-gateway` container as it will use the same configuration. The new Gateway will be mapped on a random port, to avoid collisions.