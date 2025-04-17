# Operations Guide

This document covers the common operations for managing your Tyk Demo environment.

## Basic Operations

### Starting the Environment

To start the base deployment:

```bash
./up.sh
```

The `tyk` deployment is automatically included, so it does not need to be specified.

The `bootstrap.sh` script is triggered for each deployment.

To start with specific feature deployments:

```bash
./up.sh feature1 feature2 feature3
```

Example:
```bash
./up.sh analytics-kibana instrumentation
```

### Stopping the Environment

To stop and remove all containers and volumes:

```bash
./down.sh
```

This will remove all deployments listed in `.bootstrap/bootstrapped_deployments`, including both the containers and volumes.

The `teardown.sh` script is triggered for each deployment, if it exists.

> **Warning:** The existing system state will be lost, as the volumes are removed. If you wish to persist changes, then the data must be exported - see the *Exporting Tyk Configuration* section for more info.

### Resuming a Stopped Environment

If Docker has been restarted or containers have been stopped, you can resume the existing deployments:

```bash
./up.sh
```

This will start the containers that were previously bootstrapped without rebootstrapping them.

## Environment Management

### Redeploying

To completely redeploy your environment (removing all data and starting fresh):

```bash
./down.sh && ./up.sh
```

> **Warning:** This operation will remove all data and containers. Ensure important data is exported first.

### Appending Feature Deployments

To add a feature deployment to an existing environment:

```bash
./up.sh new-feature
```

Example:
```bash
./up.sh sso
```

The script automatically detects and resumes existing deployments while adding the new one.

### Monitoring Deployment Status

Check the bootstrap log for detailed information about the deployment process:

```bash
tail -f logs/bootstrap.log
```

### Viewing Licence Status

Check the licence status:

```bash
./scripts/licences.sh
```

This will display information about licences defined in the `.env` file, including the expiry date and licence payload.

## Docker Compose Operations

Use the `docker-compose-command.sh` script for Docker Compose operations. This script generates the correct Docker Compose command for the currently active deployments, combining their `docker-compose.yml` files.

### Check Running Containers

```bash
./docker-compose-command.sh ps
```

### View Container Logs

```bash
./docker-compose-command.sh logs -f container-name
```

Example:
```bash
./docker-compose-command.sh logs -f tyk-gateway
```

### Restart a Container

```bash
./docker-compose-command.sh restart container-name
```

Example:
```bash
./docker-compose-command.sh restart tyk-dashboard
```

### Access Container Shell

```bash
./docker-compose-command.sh exec container-name bash
```

Example:
```bash
./docker-compose-command.sh exec tyk-redis bash
```

> **Note:** Bash access is not possible for Tyk containers, as they are distroless.

## Environment Variables

### Updating Environment Variables

To update environment variables in the `.env` file:

```bash
./scripts/update-env.sh VARIABLE_NAME VALUE
```

Example:
```bash
./scripts/update-env.sh DASHBOARD_LICENCE my-new-licence-key
```

### Commonly Used Environment Variables

| Variable | Description | Required |
|----------|-------------|---------|
| DASHBOARD_LICENCE | Tyk licence key | Required for all deployments |
| MDCB_LICENCE | MDCB licence key | Required only for the MDCB deployment |

If a feature deployment requires an environment variable to be manually set, it will be stated in the deployment `README.md`.

## Data Management

### Exporting Tyk Configuration

Persist changes to Tyk APIs definitions and policies by exporting the data:

```bash
./scripts/export.sh
```

This exports all API definitions and policies from the current deployment to the relevant locations within the `deployments/tyk/data/tyk-dashboard` directory. This ensures the data persists between deployments, as it will be automatically imported during the bootstrap process.

Other types of data (e.g. users) are not covered by the export script, so must be exported manually.

## Working with Postman Collections

### Importing Collections

Each deployment may include a Postman collection in its directory. To use it:

1. Open Postman
2. Click "Import" in the top left corner
3. Select the collection file from the deployment directory

The main collection is provided by the `tyk` deployment (`deployments/tyk/tyk_demo_tyk.postman_collection.json`), but many feature deployments also provide their own collections e.g. `analytics-kibana` (`deployments/analytics-kibana/tyk_demo_analytics_kibana.postman_collection.json`).

### Using Collections with Newman

For automated testing, you can use Newman (Postman's command-line collection runner). Many of the collection examples contain tests that validate the functionality. 

To run the tests:

```bash
./scripts/test.sh
```

The script runs a Newman container that tests the currently deployed environment.

**Running Newman Locally**

It's also possible to run tests locally:

```bash
newman run deployments/tyk/tyk_demo_tyk.postman_collection.json
```

> **Note:** Before running the tests, ensure that you have Newman installed and there is an active environment.

**Running Tests for All Deployments**

It's possible to run tests for all deployments:

```bash
./scripts/test-all.sh
```

This will create, test and remove each deployment in sequence.

## Plugin Management

### Plugin Build Process

Go plugins are built during the first run of `up.sh`. This process can take 5-10 minutes, depending on system performance.

To skip plugin building:

```bash
./up.sh --skip-plugin-build
```

> **Note:** Skipping plugin build will cause failures for functionality that relies on Go plugins.

### Custom Plugin Development

To add your own plugins:

1. Add plugin code to the appropriate deployment's `plugins` directory - for Go plugins, this is `deployments/tyk/volumes/tyk-gateway/plugins/go`
2. Configure an API to use the plugin, then export it using `scripts/export.sh`
3. Run `./down.sh` and then `./up.sh` to rebuild and deploy
