# Kubernetes Tyk Operator Deployment

This deployment shows how to use the Tyk Operator to automatically sync API definitions with your Tyk deployment.

The Operator monitors Kubernetes for Tyk API CRDs. When it detects a change, it perform a synchronisation with the Tyk Dashboard, adding or removing the APIs as needed. The Dashboard then synchronises the changes with the Gateways that it's managing.

## Prerequisites

The follow are required in order to use this deployment:
- Kubernetes v1.19+, with cert-manager already deployed
- Helm v3+
- Internet connection

## Setup

Run the `up.sh` script with the `k8s-operator` parameter:

```
./up.sh k8s-operator
```

This creates the deployment as part of the standard Tyk Demo bootstrap.

The process uses `kubectl` and `helm` commands to deploy the Operator and other resources into Kubernetes, with all resources deployed into a `tyk-demo` namespace.

### Kubernetes Cert Manager

The [Kubernetes Cert Manager](https://cert-manager.io/) is a prerequisite for the deployment. But since it is a centralised Kubernetes system resource, it is not installed by deployment bootstrap script. If you don't have the Cert Manager installed, you can either:
- Follow the [official installation documentation](https://cert-manager.io/docs/installation/)
- Run the `install-cert-manager.sh` script, which uses the helm chart approach as specified in the official documentation

The `install-cert-manager.sh` script can be run as follows:

```
deployments/k8s-operator/scripts/install-cert-manager.sh
```

## Removal

To remove the deployment, use the `down.sh` script as usual:

```
./down.sh
```

This will remove the containers deployed using the docker compose file, as well as the resources deployed into Kubernetes by the bootstrap process.

Note that the Kubernetes Cert Manager is not removed as part of the down.sh. As a centralised Kubernetes resource, it is not good practice for it to be arbitrarily removed by Tyk Demo.

## Configuration

No manual configuration needed. The script automatically sets up the operator and other necessary resources. The Tyk Demo context data, such as object ids and credentials are providing to the Operator, enabling it to synchronise data via the Tyk Dashboard API.

### Operator Config Script
It's possible to change the Tyk Operator configuration by running the `setup-operator-secrets.sh` script. It accepts several arguments which correspond to the various configuration options.

| Argument     | Mandatory | Description    | Default |
|--------------|-----------|------------|-----|
| `-a` | Yes | Token used for authentication with Tyk Dashboard at $tyk_url. | No default, must be provided via argument. |
| `-o` | No  | Target Tyk organisation id. | `5e9d9544a1dcd60001d0ed20` - the org id used in the standard Tyk Demo deployment |
| `-m` | No | Mode of use, either `pro` (Dashboard) or `ce` (Gateway). | `pro` - Tyk Demo is a 'pro' deployment that uses a Dashboard |
| `-n` | No | Target namespace to store the secret. | `tyk-demo` - this script is used in the context of a Tyk Demo deployment |
| `-u` | No | URL for target Tyk Dashboard. | `http://host.docker.internal:3000` - the URL to the Tyk Dashboard port mapped to the host in the standard Tyk Demo deployment |
| `-s` | No | Name of the secret used to store operator configuration. | `tyk-operator-conf` - default value used in the Operator documentation |

Example usage:
```
./deployments/k8s-operator/scripts/setup-operator-config.sh -a my-auth-token -o 5e9d9544a1dcd60001d0ed20 -m pro -n tyk-demo -u http://host.docker.internal:3000 -s tyk-operator-conf
```

## Usage

Once the deployment is complete, the operator is ready to synchronise.

### Accessing the example API

The *Operator httpbin* API is deployed using the Operator during the bootstrap process. This can be accessed using `curl`:

```
curl http://tyk-gateway.localhost:8080/operator-httpbin/get
```

This will return the typical httpbin json response.

The source CRD for this API can be found in the deployment directory `deployments/k8s-operator/data/tyk-operator/httpbin.yaml`.

### Creating an API

Use `kubectl apply` with the *Hello World* CRD to generate an API definition resource in Kubernetes:

```
kubectl -n tyk-demo apply -f deployments/k8s-operator/data/tyk-operator/hello-world.yaml
```

You will see the response:

```
apidefinition.tyk.tyk.io/hello-world created
```

The CRD will be listed as a `tykapis` resource, as shown by this `kubectl` command:

```
kubectl -n tyk-demo get tykapis
```

Displays both the newly created *hello world* API as well as the *httpbin example* API created by the bootstrap script:

```
NAME              DOMAIN   LISTENPATH              PROXY.TARGETURL   ENABLED   STATUS
hello-world                /operator-hello-world   http://httpbin    true      Successful
httpbin-example            /operator-httpbin       http://httpbin    true      Successful
```

By this point, the Operator will have processed the CRD and reconciled the changes with the Dashboard, which in turn will have updated the Gateway. You will be able to see the *Operator hello world* API listed in the [Dashboard APIs page](http://tyk-dashboard.localhost:3000/apis), as well as access the API via the Gateway. Try running a simple `curl` request to see it in action:

```
curl http://tyk-gateway.localhost:8080/operator-hello-world/get
```

### Displaying Tyk APIs in Kubernetes

Use `kubectl get` to display the Tyk APIs deployed in the `tyk-demo` namespace. For example:

```
kubectl -n tyk-demo get tykapis
```

This will display something similar to:

```
NAME              DOMAIN   LISTENPATH              PROXY.TARGETURL   ENABLED   STATUS
httpbin-example            /operator-httpbin       http://httpbin    true      Successful
```

### Deleting an API

To delete an API, use `kubectl delete`. For example:

```
kubectl -n tyk-demo delete tykapis httpbin-example
```

The Operator will synchronise this change, removing the API from the Tyk Dashboard and Gateway. Attempting to access the API will result in a `404 Not Found` response:

```
curl http://tyk-gateway.localhost:8080/operator-httpbin/get
```
