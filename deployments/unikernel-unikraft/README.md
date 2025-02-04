# Unikernel Unikraft Deployment

This guide explains how to deploy the Tyk Gateway as a unikernel on Unikraft Cloud.

## Overview

Unikraft is a unikernel development framework that enables the creation of lightweight, highly optimised unikernels. This deployment package builds and runs Tyk Gateway as a unikernel on Unikraft Cloud.

The deployment sets up Tyk Gateway as a data plane gateway, which connects to a locally running MDCB service via an Ngrok tunnel.

## Prerequisites

### 1. Tyk Licences

Ensure that your Tyk and MDCB licences are set in the Tyk Demo `.env` file:

```shell
DASHBOARD_LICENCE=<YOUR_TYK_DASHBOARD_LICENCE>
MDCB_LICENCE=<YOUR_TYK_MDCB_LICENCE>
```

The deployment will fail if the correct licences are not provided.

### 2. Unikraft CLI

Install the Unikraft CLI (`kraft`). The bootstrap process will not proceed without it.

Follow the [Unikraft CLI installation guide](https://unikraft.org/docs/cli/install) for setup instructions.

### 3. Unikraft Cloud Credentials

Access to Unikraft Cloud is required, including an API token and a metro (deployment) region. Add these to the Tyk Demo `.env` file:

```shell
UKC_TOKEN=<YOUR_UNIKRAFT_CLOUD_ACCESS_TOKEN>
UKC_METRO=<YOUR_UNIKRAFT_CLOUD_METRO>
```

Sign up for Unikraft Cloud [here](https://console.unikraft.cloud/signup). The free tier is sufficient for this deployment.

### Ngrok Access Token

An Ngrok tunnel is required to allow the Unikraft-hosted gateway to communicate with the local MDCB instance.

Add your Ngrok token to the Tyk Demo `.env` file:

```shell
NGROK_AUTHTOKEN=<YOUR_NGROK_AUTH_TOKEN>
```

See the [Ngrok authentication guide](https://ngrok.com/docs/agent/#authtokens) for details. The free plan is sufficient.

## Deployment

This section explains how to deploy and remove this deployment. It covers starting the deployment, tearing it down, and accessing the deployed API.

### Starting the Deployment

Run the following script to start the deployment:

```shell
./up.sh mdcb unikernel-unikraft
```

Note: The `mdcb` deployment is required for this deployment to function correctly.

### Stopping and Removing the Deployment

To remove the deployment and associated resources from Unikraft Cloud, run:

```shell
./down.sh
```

This triggers the `teardown.sh` script, which cleans up the Unikraft Cloud resources.

### Accessing the Deployed API

This deployment includes a sample API defintion configured to proxy requests to http://httpbin.org. The API and gateway are tagged with `unikraft`, ensuring only this API is loaded by the gateway.

Unikraft Cloud assigns a dynamic hostname to the gateway (e.g., `red-firefly-y3wdmb5a.fra0.kraft.host`). This hostname is displayed in the deployment bootstrap script output e.g. 

```shell
▼ Unikernel - Unikraft
  ▽ Unikraft Cloud
            Gateway URL : https://red-firefly-y3wdmb5a.fra0.kraft.host
        Example API URL : https://red-firefly-y3wdmb5a.fra0.kraft.host/unikraft/get
```

To test the API, use:

```shell
curl https://<YOUR_GATEWAY_HOSTNAME>/unikraft/get
```

Note that HTTPS is used. If successful, you will receive a JSON response.

## Unikraft

This section explains how the Tyk Gateway unikernel is built, configured, and deployed on Unikraft Cloud. It covers the build process, cloud configuration, and service definitions, along with boot performance observations.

### Building the Tyk Gateway Unikernel

The Tyk Gateway unikernel is built using resources in the [unikraft directory](unikraft). The [Dockerfile](unikraft/Dockerfile) controls the build process and uses the `TYK_VERSION` argument to specify the Tyk Gateway branch.

The build process consists of multiple stages:
- Compiling the Tyk Gateway binary from source.
- Copying essential system files, such as certificates.
- Creating a lightweight unikernel container with only the necessary binaries and configuration.

### Unikraft Cloud Settings

The deployment enables Unikraft Cloud’s *scale to zero* functionality, suspending the gateway when idle and restoring its state when needed.

These settings are defined in the [Kraftfile](unikraft/Kraftfile):

```yaml
labels:
  cloud.unikraft.v1.instances/scale_to_zero.policy: "idle" # idle instances will be scaled to zero
  cloud.unikraft.v1.instances/scale_to_zero.stateful: "true" # instance state is restored when scaling from zero
  cloud.unikraft.v1.instances/scale_to_zero.cooldown_time_ms: 5000 # time to wait until setting gateway to standby
```

### Boot Performance Observations

With the configuration defined in this deployment, the Tyk Gateway typically boots in ~100ms on first startup. It then takes a short time to load API definitions from MDCB before it is ready to proxy requests.

When scaling up from zero, the boot time is significantly reduced to ~10ms, benefiting from Unikraft's stateful scaling functionality, which restores the previous state.

### Service Definitions

A [Docker Compose file](unikraft/compose.yml) defines the services deployed on Unikraft Cloud. This deployment includes a Tyk Gateway and Redis instance, with MDCB configuration automatically injected via environment variables.

```yaml
  gateway:
    build: .
    ports:
      - 443:8080
    environment:
      - TYK_GW_SLAVEOPTIONS_CONNECTIONSTRING=${MDCB_URL}
      - TYK_GW_SLAVEOPTIONS_APIKEY=${MDCB_KEY}
    mem_reservation: 1024M
```
