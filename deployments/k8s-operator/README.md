# Kubernetes Tyk Operator Deployment

This deployment shows how to use the Tyk Operator to automatically sync API definitions with your Tyk deployment.

The Operator monitors Kubernetes for Tyk API CRDs. When it detects a change, it perform a synchronisation with the Tyk Dashboard, adding or removing the APIs as needed. The Dashboard then synchronises the changes with the Gateways that it's managing.

## Prerequisites

The follow are required in order to use this deployment:
- Docker Desktop with Kubernetes enabled
- Helm
- Internet connection

## Setup

Run the `up.sh` script with the `k8s-operator` parameter:

```
./up.sh k8s-operator
```

This perform the standard Tyk Demo bootstrap and also installs the Tyk Operator into the local Docker Desktop Kubernetes environment.

### Configuration

No manual configuration needed. The script automatically sets up secrets for the Operator using the Tyk Demo credentials, providing the Operator with the information it needs to synchronise data via the Tyk Dashboard API.

In the event that your Tyk Demo credentials change, run `./scripts/setup-operator-secrets.sh` and restart the Operator container. This avoids having to rebootstrap the whole deployment.

## Usage

Once the deployment is complete, the operator is ready to synchronise.

### Creating an API

Use `kubectl apply` with the example HTTPbin CRD to generate an API definition resource in Kubernetes:

```
kubectl apply -f deployments/k8s-operator/data/tyk-operator/httpbin.yaml
```

You will see the response:

```
apidefinition.tyk.tyk.io/operator-httpbin
```

The CRD will be listed as a `tykapis` resource, as shown by this `kubectl` command:

```
kubectl get tykapis
```

Displays:

```
NAME               DOMAIN   LISTENPATH          PROXY.TARGETURL   ENABLED   STATUS
tyk-operator-httpbin-example            /operator-httpbin   http://httpbin    true      Successful
```

The Operator quickly detects this change, and automatically processes the CRD and creates a new API Definition in the Dashboard. You will be able to see the "Operator httpbin" API listed in the [Dashboard APIs page](http://tyk-dashboard.localhost:3000/apis), as well as access the API via the Gateway. Try running a simple `curl` request to see it in action:

```
curl http://tyk-gateway.localhost:8080/operator-httpbin/get
```

### Displaying Tyk APIs in Kubernetes

Use `kubectl get tykapis` to display the Tyk APIs stored in Kubernetes:

```
NAME               DOMAIN   LISTENPATH          PROXY.TARGETURL      ENABLED   STATUS
operator-httpbin            /operator-httpbin   http://httpbin       true      Successful
```

### Deleting an API

To delete an API, use `kubectl delete`. For example:

```
kubectl delete tykapis operator-httpbin
```

The Operator will synchronise this change, removing the API from the Tyk Dashboard and Gateway. Attempting to access the API will result in a `404 Not Found` response:

```
curl http://tyk-gateway.localhost:8080/operator-httpbin/get
```
