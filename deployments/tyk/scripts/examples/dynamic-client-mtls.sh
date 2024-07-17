#!/bin/bash

# Run this script from the repo root e.g. ./deployments/tyk/scripts/examples/dynamic-client-mtls.sh

# The script calls an API is configured to allow client certificate authentication.
# The public key is registered in the dashboard, along with an API key, which is associated with the certificate and provides the access rights to the API.
# The gateway uses the certificate provided in the request to match the API key and authorise access to the requested endpoint.
# The -k flag is used to ignore certificate error associated with the gateway's self-signed certificate.

curl -k \
    --cert deployments/tyk/data/tyk-dashboard/1/certs/cert-1-mtls_example.pem \
    --key deployments/tyk/data/misc/dynamic-client-mtls/mtls-private-key.pem \
    https://tyk-gateway-2.localhost:8081/dynamic-client-mtls/get