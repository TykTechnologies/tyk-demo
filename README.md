[![Tyk Demo Tests](https://github.com/TykTechnologies/tyk-demo/actions/workflows/tyk-demo-tests.yml/badge.svg)](https://github.com/TykTechnologies/tyk-demo/actions/workflows/tyk-demo-tests.yml)

# Tyk Demo

A ready-to-run sandbox for exploring Tyk’s API management platform through practical, hands-on use.

Tyk Demo provides:
- Pre-configured deployments showcasing various Tyk capabilities
- Automated setup and bootstrapping
- Postman collections and scripts for interactive exploration
- A modular structure for mixing and matching features of interest

While created primarily for Tyk's technical staff, anyone interested in exploring Tyk functionality can benefit from this sandbox environment.

> **Note:** This repository was developed and tested on macOS using Docker Desktop. The instructions provided are tailored for this setup. Users on other operating systems may encounter differences and should adapt accordingly.

## Getting Started

### Prerequisites

- Docker Desktop with Docker Compose
  - Recommended 4GB RAM allocated for Docker resources
- `jq` command-line utility
- A valid Tyk license
- (Optional) A valid MDCB license

### Quick Start

Follow these steps to get started. For more detailed instructions and advanced information, see the [Detailed Setup Guide](docs/SETUP.md).

**1. Clone the repository**

```bash
git clone https://github.com/TykTechnologies/tyk-demo.git
cd tyk-demo
```

**2. Configure local DNS entries**

```bash
sudo ./scripts/update-hosts.sh
```

> **Note:** You may be prompted for your password due to the use of `sudo`.

**3. Add your licence**

Use this command to apply your Tyk licence, replacing `YOUR_LICENCE_KEY` with your actual licence key:

```bash
./scripts/update-env.sh DASHBOARD_LICENCE YOUR_LICENCE_KEY
```

If you also have a licence for MDCB, that can also be added:

```bash
./scripts/update-env.sh MDCB_LICENCE YOUR_MDCB_LICENCE_KEY
```

**4. Launch the environment**

```bash
./up.sh
```

Wait until you see the message "Tyk Demo initialisation process completed". The environment details, including usernames, password and API keys will also be shown at this point.

> **Note:** On the first run, the Go plugins will be built. This can take 5–10 minutes or longer, depending on your system’s performance. The build is cached for future runs. To skip building the plugins, use the `--skip-plugin-build` flag, but any functionality that depends on Go plugins could be affected.

**5. Access the Tyk dashboard**

Use the credentials shown in the output to log in to the [Tyk Dashboard](http://tyk-dashboard.localhost:3000).

**6. Import the Postman collection**

Import the [provided collection](deployments/tyk/tyk_demo_tyk.postman_collection.json) into Postman to explore Tyk's functionality.

## Architecture

Tyk Demo uses a modular approach:

- **Base deployment**: Core Tyk components (Gateway, Dashboard, Pump) with supporting databases
- **Feature deployments**: Optional extensions (analytics, SSO, observability etc.)

The base deployment is always active. Feature deployments can be added selectively.

### Available Feature Deployments

| Feature Deployment                  | Description                                                                 |
|-------------------------------------|-----------------------------------------------------------------------------|
| [Analytics to Datadog](deployments/analytics-datadog/README.md) | Export analytics data to Datadog for monitoring and visualization. |
| [Analytics to Kibana](deployments/analytics-kibana/README.md) | Export analytics data to Kibana for log analysis and visualization. |
| [Analytics to Splunk](deployments/analytics-splunk/README.md) | Export analytics data to Splunk for advanced analytics and monitoring. |
| [Bench test suite](deployments/bench/README.md) | Run performance and load testing for Tyk deployments. |
| [CI/CD with Jenkins](deployments/cicd/README.md) | Integrate Tyk with Jenkins for continuous integration and deployment. |
| [Postgres database](deployments/database-postgres/README.md) | Migrate from MongoDB to Postgres. |
| [Federation](deployments/federation/README.md) | Enable multi-region or multi-cloud API management with Tyk Federation. |
| [Healthcheck Blackbox](deployments/healthcheck-blackbox/README.md) | Monitor Tyk system health using Prometheus and Blackbox Exporter. |
| [Instrumentation](deployments/instrumentation/README.md) | Add instrumentation for monitoring and debugging. |
| [Kubernetes Operator](deployments/k8s-operator/README.md) | Use the Tyk K8s Operator to configure the Dashboard. |
| [Keycloak](deployments/keycloak-dcr/README.md) | Integrate with Keycloak for dynamic client registration. |
| [NGINX Load Balancer](deployments/load-balancer-nginx/README.md) | Use NGINX to load balance Tyk Gateways. |
| [Mail server](deployments/mailserver/README.md) | Set up a mail server for email notifications and testing. |
| [MDCB](deployments/mdcb/README.md) | Deploy Multi-Data Center Bridge for distributed API management. |
| [MQTT](deployments/mqtt/README.md) | Enable MQTT protocol support for IoT use cases. |
| [OpenTelemetry with Jaeger](deployments/otel-jaeger/README.md) | Use OpenTelemetry with Jaeger for distributed tracing. |
| [OpenTelemetry with New Relic](deployments/otel-new-relic/README.md) | Use OpenTelemetry with New Relic for distributed tracing. |
| [Python gRPC server](deployments/plugin-grpc-python/README.md) | Example deployment of a Python-based gRPC plugin server. |
| [Enterprise Portal](deployments/portal/README.md) | Deploy the Tyk Enterprise Developer Portal. |
| [SLIs with Prometheus/Grafana](deployments/slo-prometheus-grafana/README.md) | Monitor Service Level Indicators and Objectives with Prometheus and Grafana. |
| [Single Sign-On](deployments/sso/README.md) | Enable Single Sign-On for Tyk Dashboard and Portal. |
| [Subscriptions](deployments/subscriptions/README.md) | Use GraphQL to service websocket subscriptions. |
| [Tyk 2](deployments/tyk2/README.md) | Add a second Tyk environment. |
| [Unikernel Unikraft](deployments/unikernel-unikraft/README.md) | Deploy the Tyk Gateway as a unikernel. |
| [WAF](deployments/waf/README.md) | Add Web Application Firewall capabilities to your deployment. |

## Common Operations

### Add Feature Deployments

Append feature deployment names to the `up.sh` command:

```bash
./up.sh analytics-kibana instumentation
```

### Stop and Remove

Tear down the environment and remove Docker resources:

```bash
./down.sh
```

### Resume a Paused Deployment

Start existing Tyk Demo containers that are currently stopped:

```bash
./up.sh
```

### Expand a Running Deployment

Append feature deployment names to the `up.sh` command:

```bash
./up.sh sso
```

### Use Docker Compose Directly

Use `docker-compose-command.sh` to generate the correct Docker Compose command for your environment.

Check running containers:

```bash
./docker-compose-command.sh ps
```

View logs:

```bash
./docker-compose-command.sh logs -f tyk-gateway
```

Restart a service:

```bash
./docker-compose-command.sh restart tyk-dashboard
```

## Troubleshooting
Check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md) for solutions to common issues.

## Contributing
Contributions are welcome. See the [Contributor Guide](CONTRIBUTING.md) for more information.






# Tyk Demo

Tyk Demo offers a pre-configured deployment that includes various examples showcasing Tyk's capabilities. Powered by Docker Compose for swift setup, it allows you to pick and choose the features you want to explore.

The primary use case for Tyk Demo is to act as a centralised knowledge sharing resource for client-facing technical Tyk staff. However, anyone curious about Tyk can benefit from Tyk Demo. It's hands-on sandbox environment allows anyone to experiment and learn more about Tyk's features.

Postman collections are included for some deployments. These are pre-configured to interact with the features and functionality available in the deployments, making it easy to explore and experience Tyk.

See the [Contributor Guide](CONTRIBUTING.md) for information on how to contribute to and extend this repository.

> :warning: Please note that this repo has been created on MacOS with Docker Desktop for Mac. You may experience issues if using a different operating system or approach.

If you encounter a problem using this repository, please try to fix it yourself and create a pull request so that others can benefit.

# Overview

This project leverages a concept of deployments, enabling users to choose what gets deployed.

- **Base deployment**: The mandatory deployment that provides standard Tyk components (Gateway, Dashboard, Pump), databases (Redis and MongoDB), and other supporting software to enhance the demo experience.
- **Feature deployments**: Extend the base deployment functionality. These deployments cover specific scenarios for Tyk, such as single sign-on, analytics export, etc.

Each deployment has a dedicated directory containing all necessary deployment files and additional information.

This approach focuses on simplicity. Running a single command triggers Docker Compose to create containers, and bootstrap scripts initialise the environment. Everything is handled automatically, from configuration application to data population.

## Requirements

### License requirements
- Get a valid [Tyk Self-Managed license](https://tyk.io/pricing-self-managed/) key (click **"start now"** under **Free trial**). **This is a self-service option!**
- If you want to run the MDCB deployment (distributed set up with control plane and data planes), then you need to [contact the Tyk team](https://tyk.io/pricing-self-managed/) to get an MDCB license key.

### Software
The base deployment requires:
- Docker Desktop, with Docker Compose
- jq

Note that some feature deployments may have additional requirements. See deployment readmes for more information.

## Repository Structure

* `deployments/*`: Contains all the deployments available as sub-directories
* `test.postman_environment.json`: Set of environment variables, for use when running tests with a Newman container within a Docker deployment
* `scripts/*.sh`: Some useful commands encapsulated in scripts
* `up.sh`: Brings up the deployment
* `down.sh`: Takes down the deployment

## Deployments

The deployment directories (`deployments/*`) contain the various deployments which can be made with this repo. The *base deployment* is in the `deployments/tyk` directory. The other directories are *feature deployments*, which extend the base deployment functionality and require the base deployment in order to function correctly.

All of the directories contain `docker-compose.yml`, `bootstrap.sh` and `README.md` files specific to the deployment. They may also contain directories called `data` or `volumes`, which hold the data necessary during bootstrapping or providing as mapped volumes into the container.

### Feature Deployments
* [Analytics to Datadog](deployments/analytics-datadog/README.md)
* [Analytics to Kibana](deployments/analytics-kibana/README.md)
* [Analytics to Splunk](deployments/analytics-splunk/README.md)
* [Bench test suite](deployments/bench/README.md)
* [CI/CD with Jenkins](deployments/cicd/README.md)
* [Federation](deployments/federation/README.md)
* [Instrumentation](deployments/instrumentation/README.md)
* [Keycloak](deployments/keycloak-dcr/README.md)
* [Mail server](deployments/mailserver/README.md)
* [MDCB](deployments/mdcb/README.md)
* [MQTT](deployments/mqtt/README.md)
* [OpenTelemetry with Jaeger](deployments/otel-jaeger/README.md)
* [Enterprise Portal](deployments/portal/README.md)
* [Python gRPC server](deployments/plugin-grpc-python/README.md)
* [SLIs and SLOs with Prometheus and Grafana](deployments/slo-prometheus-grafana/README.md)
* [SSO](deployments/sso/README.md)
* [WAF](deployments/waf/README.md)
* (deprecated) [OpenTracing/Zipkin]


## Environment variables

The `docker-compose.yml` files in this repo use Docker environment variables to set OS environment variables for the Dashboard, Gateway and Pump containers. This allows aspects of the Tyk and Docker configuration to be overridden without having to make changes to the source configuration files.

As per standard Docker convention, the Docker environment variables are stored in a file called `.env`, which is in the repository root directory.

You can use `.env.example` as a starting point for your `.env` file.

You must set `DASHBOARD_LICENCE` variable with the valid license key you previously got. 
If you are using the MDCB (`mdcb`) deployment, then you need to do the same for `MDCB_LICENCE` variable.


### Notable environment variables are:


There are various other environment variables used, but it's not normally necessary to set them. See the [Tyk environment variables documentation](https://tyk.io/docs/tyk-environment-variables/) for more information. The exception being the variables used for the DataDog Analytics deployment (`analytics-datadog`), which has its own set of variables for configuring the DataDog integration - see the [Setup section of that deployment's readme](https://github.com/TykTechnologies/tyk-demo/blob/master/deployments/analytics-datadog/README.md#setup) for more information.

Unless you have a specific reason to do so, it's not recommended to set the `*_VERSION` environment variables e.g. `GATEWAY_VERSION`. Doing so will effectively pin the image tag of the container, which could cause the `bootstrap.sh` scripts to fail, as they are written to operate against the image tags specified in the `docker-compose.yml` files.

Many of the containers are configured to use `.env` as an environment file. This means that any standard Tyk environment variables added to `.env` will be available in the container e.g. setting `DB_AUDIT_ENABLED=true` enables auditing in the Dashboard.

# Getting Started

## Step 1: Install dependencies

### Docker

Docker is required. Follow the [Docker installation guide](https://docs.docker.com/get-docker/) for your platform.

Docker Compose is required (v2.x+ recommended). If you're installing on Mac or Windows, then Docker Compose is already included as part of the base Docker install, so you don't need to do anything else. For Linux, follow the [Docker Compose installation guide](https://docs.docker.com/compose/install/).

### JQ

The bootstrap script uses JQ for extracting data from JSON objects, it can be installed as follows.

Install on OS X using Homebrew:

```bash
brew install jq
```

Install on Debian/Ubuntu using APT:

```bash
sudo apt-get install jq
```

See the [JQ installation page](https://stedolan.github.io/jq/download/) for other operating systems.

## Step 2: Map Tyk Demo hostnames to localhost IP

Run the `update-hosts.sh` script to add host entries for the Tyk Dashboard and Portal to `/etc/hosts`:

```bash
sudo ./scripts/update-hosts.sh
```

The custom hostnames will be used by the Dashboard and Gateway to:

- Differentiate between requests for the Dashboard and Portal
- Identify the API being requested when using custom domains

## Step 3: Add Docker Environment variables

The `tyk/docker-compose.yml` and `tyk2/docker-compose.yml` files use a Docker environment variable to set the dashboard licence. To set this, create a file called `.env` in the root directory of the repo, then set the content of the file as follows, replacing `<YOUR_LICENCE>` with your Dashboard licence:

```env
DASHBOARD_LICENCE=<YOUR_LICENCE>
```

In addition to this, some features require entries in the `.env` file. These are set automatically by the `up.sh` file, depending on the deployment parameters.

> :information_source: Your Tyk licence must be valid for at least two Gateways.

## Step 4: Bring the deployment up

To bootstrap the system we will run the `up.sh` script, which will run the necessary `docker compose` and `bootstrap` commands to start the containers and bootstrap the system. 

```bash
./up.sh
```

The script displays a message, showing the deployments it will create. For example:

```
Deployments to create:
  tyk
```

This will bring up the standard Tyk deployment, after which you can log into the Dashboard and start using Tyk.

### Deploying a feature

If you want to deploy features, run the `up.sh` command, passing a parameter of the directory name of the feature to deploy. For example, to deploy both the standard Tyk deployment and the `analytics-kibana` deployment:

```
./up.sh analytics-kibana
```

The feature names are the directory names from the `deployments` directory.

### Deploying multiple features at the same time

Multiple features can be deployed at the same time by providing multiple feature parameters. For example, to deploy `analytics-kibana` and `instrumentation`:

```bash
./up.sh analytics-kibana instrumentation
```

### Bootstrap logging

The bootstrap scripts provide feedback on progress in the `logs/bootstrap.log` file.

## Step 5: Log into the Dashboard

The bootstrap process provides credentials and other useful information in the terminal output. Check this output for the Dashboard credentials.

When you log into the Dashboard, you will find the imported APIs and Policies are now available.

## Step 6 (optional): Import Postman collection

There are Postman collections which complement the deployments. They contain many example requests which demonstrate Tyk features and functionality in the deployments. If a deployment has a collection it will be in the deployment directory.

The collection for the base *Tyk* Deployment is called `tyk_demo.postman_collection.json`. Import it into [Postman](https://postman.com) to start making requests.

# Resetting

If you want to reset your environment, you need to remove the volumes associated with the container as well as the containers themselves. The `down.sh` script can do this for you.
You don't need to declare which component to remove, since they have already been registered in `.bootstrap/bootstrapped_deployments` by the `up.sh` script. The `down.sh` script will simply remove the deployments listed in that file.

To delete the containers and associated volumes:

```bash
./down.sh
```

The script displays a message, showing the deployments it intends to remove. For example:

```
Deployments to remove:
  tyk
```

# Resuming

Deployments can be resumed if their containers have stopped. This is useful for situations where you want to resume using Tyk Demo after its containers have been stopped, such as when Docker is restarted. Resuming deployments uses the existing containers and volumes, which means that the deployment resumes using its previous state. As such, it's not necessary to rebootstrap the deployment, as all the necessary data is already available.

The script automatically determines which deployments to resume by reading the deployments listed in `.bootstrap/bootstrapped_deployments`.

To resume deployments, run the `./up.sh` command:

```bash
./up.sh
```

The script will display the deployments to be resumed. For example:

```
Deployments to resume:
  tyk
```

If you want to rebootstrap the deployments, then run the `./down.sh` script before running `./up.sh`. This will remove the containers and volumes of the existing deployments, which then allows the `./up.sh` script to bootstrap the deployments.

# Redeploying

To redeploy an existing deployment, run the `./down.sh` script followed by the `./up.sh` script:

```bash
./down.sh && ./up.sh
```

This deletes the containers and volumes associated with the existing deployment, then creates a new deployment based on the `up.sh` command. 

# Appending to an existing deployment

Feature deployments can be added to existing deployments by running the `up.sh` script consecutively. This avoids having to remove the existing deployment with the `down.sh` script.

For example, if `./up.sh` has already been run, there will be a standard `tyk` deployment currently deployed. To add the `sso` deployment to the existing deployment, run:

```bash
./up.sh sso
```

Note that existing deployments do not need to be specified. The script detects existing deployments and automatically resumes them. A message is displayed to confirm the situation:

```
Deployments to resume:
  tyk
Note: Resumed deployments are not rebootstrapped - they use their existing volumes
Tip: To rebootstrap deployments, you must first remove them using the down.sh script
Deployments to create:
  sso
```

# Check running containers, logs, restart

It is difficult to use the usual docker-compose command in this project since we have various files and project directories. To make commands such as `ps` or `restart` easier to run I have created the script `./docker-compose-command.sh`. You can use it in the same way as you would with docker-compose:
- To check running processes: `./docker-compose-command.sh ps`
- To restart the gateway: `./docker-compose-command.sh restart tyk-gateway`
- To tail the logs in the Redis container: `./docker-compose-command.sh logs -f tyk-redis`
- To bash into redis container: `./docker-compose-command.sh exec tyk-redis bash`

# Troubleshooting

### Tyk Demo installation hasn't finished with the usual output of hostnames and a password to login into the Dashboard
The license key might be missing or expired. You can see a message about it in *bootstrap.log*.
You can use `./scripts/update-licence.s` to quickly update the licence key

```bash
./scripts/update-licence.sh my-licence-key
```


### Application error when opening the documentation in the portal

You will also see an error in the field that has the base64 encoding of the OAS in the catalogue document.
Since the value cannot be base64 *decoded* it means that the base64 *encoding* failed during bootstrap.
One possible reason is that you are using Brew's base64 binary since Brew's version inserts `\r` to the output rather than just output the base64 encoding as is. You can run `whereis base64` to find out. The expected path should be `/usr/bin/base64`.

