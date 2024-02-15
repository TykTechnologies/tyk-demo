# Kubernetes Tyk Operator Deployment

This deployment demonstrates how the Tyk Operator automatically keeps API definitions in sync between Kubernetes and your Tyk Dashboard.

The Tyk Operator acts as your Kubernetes API management assistant, automating the tedious setup and updates. Here's what it does:
- **Watches Kubernetes API CRDs**: Your API definitions are stored in Kubernetes as Custom Resource Definitions (CRDs). The Operator monitors these for any changes you make.
- **Syncs with Tyk Dashboard**: If it detects a change, it seamlessly talks to the Tyk Dashboard, adding or removing the corresponding API as needed.
- **Dashboard informs Gateways**: The Dashboard acts as the central command centre, broadcasting the updates to all connected Tyk Gateways.

This means:
- **No manual configuration**: Focus on developing APIs, and the Operator handles the deployment behind the scenes.
- **Declarative management**: Define your APIs in CRDs, and the Operator ensures every Gateway reflects those changes.
- **Consistent state**: Forget about configuration drift. The Operator keeps everything in sync, even across multiple Gateways.

Think of it as infrastructure as code for your APIs, giving you a robust and automated way to manage them within your Kubernetes environment.

## Prerequisites

Kubernetes:
- Version 1.19 or later
- Active Cert Manager deployment

Helm:
- Version 3 or later

Compatibility:
- This deployment is intended for use with Docker Desktop's embedded Kubernetes environment. However, it should also work on other Kubernetes installations.
- Ensure both `kubectl` and `helm` commands are functioning correctly on your system.

## Setup

Ensure you have `kubectl` and `helm` tools installed and configured with access to your Kubernetes cluster.

For Docker Desktop users, ensure that the embedded Kubernetes is enabled.

When you are ready to begin, open your terminal, navigate to the Tyk Demo root directory and run:

```
./up.sh k8s-operator
```

This script automates the deployment process using `kubectl` and `helm`. It sets up the Operator and related resources within the `tyk-demo` namespace in your Kubernetes cluster.

### Kubernetes Cert Manager

This deployment requires the [Kubernetes Cert Manager](https://cert-manager.io/). Installing it is outside the scope of the bootstrap script.

Installation Options:
- **Manual Installation**: Follow the official installation documentation (https://cert-manager.io/docs/installation/) for detailed instructions. This approach offers maximum flexibility and control.
- **Simplified Installation**: Run the provided `install-cert-manager.sh` script, which uses the Helm chart method described in the official documentation. This script provides a simple, quick setup.

Running the script:

```
./deployments/k8s-operator/scripts/install-cert-manager.sh
```

## Removal

To remove the deployment, execute the `down.sh` script:

```
./down.sh
```

This script automates the removal process:
- **Docker Containers**: Removes all Docker containers, volumes and networks spun up from the standard docker-compose bootstrap process
- **Kubernetes Resources**: Removes the `tyk-demo` namespace from Kubernetes, along with all the resources provisioned within it during the *Kubernetes Operator* deployment bootstrap

**Important Note**: The Kubernetes Cert Manager is not removed by the `down.sh` script. The Cert Manager functions as a central resource within your Kubernetes cluster, potentially managing certificates for various applications. Deleting it could disrupt other services that rely on it. If you wish to remove it, please do so manually.

## Configuration

No manual configuration needed. The script automatically sets up the Operator and other necessary resources. The Tyk Demo context data, such as object ids and credentials, are provided to the Operator, enabling it to synchronise data via the Tyk Dashboard API.

### Operator Config Script
It's possible to change the Tyk Operator configuration by running the `setup-operator-secrets.sh` script. Note that this is not normally necessary, as the bootstrap process automatically performs the configuration. However, if you make changes that necessitate changes to the Tyk Operator config, then this script may be useful.

The script accepts several arguments which correspond to the various configuration options:

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

The Operator is ready to use once the bootstrap has finished.

### Accessing the example API

The *Operator httpbin* API is automatically deployed as part of the initial bootstrap process.

It's accessible using the following curl command:

```
curl http://tyk-gateway.localhost:8080/operator-httpbin/get
```

This command will return the standard httpbin JSON response, verifying successful connectivity and functionality.

Notes:
- The CRD for this API is located at `deployments/k8s-operator/data/tyk-operator/httpbin.yaml`
- The API is deployed under the `/operator-httpbin` prefix within the Tyk Gateway instance
- This implementation serves as a basic demonstration of the Operator's capabilities and can be customised or extended according to specific needs

### Creating an API

#### 1. Apply the CRD

Use `kubectl apply` to deploy a CRD YAML file representing your API definition. This example uses the provided `hello-world.yaml` file:

```
kubectl -n tyk-demo apply -f deployments/k8s-operator/data/tyk-operator/hello-world.yaml
```

Expect the response:

```
apidefinition.tyk.tyk.io/hello-world created
```

#### 2. Verify CRD Creation

Confirm the successful deployment of the CRD using `kubectl`:

```
kubectl -n tyk-demo get tykapis
```

This should display both the newly created `hello-world` API and any existing ones (e.g. `httpbin-example`):

```
NAME              DOMAIN   LISTENPATH              PROXY.TARGETURL   ENABLED   STATUS
hello-world                /operator-hello-world   http://httpbin    true      Successful
httpbin-example            /operator-httpbin       http://httpbin    true      Successful
```

#### 3. Verify Synchronisation

The Tyk Operator processes the CRD, synchronising it with the Tyk Dashboard, which updates the Gateways accordingly.

Verifying reconciliation process:

1. API is listed in the Dashboard
In the [Dashboard APIs page](http://tyk-dashboard.localhost:3000/apis), you should see the newly created *Operator hello world* API listed amongst others.

2. API is accessible via the Gateway
Execute a simple `curl` request to verify API accessibility:

```
curl http://tyk-gateway.localhost:8080/operator-hello-world/get
```

A successful response indicates the API is functioning correctly.

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

The Operator will synchronise this change, removing the API from the Tyk Dashboard and Gateway. 

Attempting to access the API after it's been deleted will result in a `404 Not Found` response. For example, running the following command will return a `404` error:

```
curl http://tyk-gateway.localhost:8080/operator-httpbin/get
```
