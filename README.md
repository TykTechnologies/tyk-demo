[![Tyk Demo API Tests](https://github.com/TykTechnologies/tyk-demo/actions/workflows/tyk-demo-tests.yml/badge.svg)](https://github.com/TykTechnologies/tyk-demo/actions/workflows/tyk-demo-tests.yml)

# Tyk Demo

This repo provides an example installation of Tyk. It uses Docker Compose to provide a quick, simple deployment, where you can choose what features to include.

It has been built to enable the sharing of knowledge and combining of effort amongst client-facing technical Tyk folks.

See the [Contributor Guide](CONTRIBUTING.md) for information on how to contribute to and extend this repository.

> :warning: Please note that this repo has been created on Mac OS X with Docker Desktop for Mac. You may experience issues if using a different operating system or approach. 

If you encounter a problem using this repository, please try to fix it yourself and create a pull request so that others can benefit.

# Overview

The concept is that there is a **base deployment** of Tyk, which gives you the usual Tyk components: Gateway, Dashboard, Pump, plus the databases Redis and MongoDB. This standard deployment can be extended by including additional **feature deployments** as needed. The feature deployments cover particular scenarios for Tyk, such as:

* Single sign on
* Analytics export
* Tracking
* CI/CD
* 2nd Tyk Environment
* Instrumentation

Each feature deployment has its own directory, with the necessary files to deploy the feature and a readme to describe how to use it.

There is a focus on simplicity. Docker Compose is used to provision the containers, and bootstrap scripts are used to initialise the environment so that it is ready to use straight away - applying configuration and populating data.

## Requirements

### License requirements
- Get a valid [Tyk Self-Managed license](https://tyk.io/pricing-self-managed/) key (click **"start now"** under **Free trial**). **This is a self-service option!**
- If you want to run MDCB deployment (distributed set up with control plane and data plans), then you need to [contact Tyk team](https://tyk.io/pricing-self-managed/) to get a license key. Please leave it if it's the first time you are trying out Tyk and you are not in a position to get engaged at this moment.

### Software
docker compose

## Repository Structure

* `deployments/*`: Contains all the deployments available as sub-directories
* `test.postman_environment.json`: Set of environment variables, for use when running tests with a Newman container within a Docker deployment
* `scripts/*.sh`: Some useful commands encapsulated in scripts
* `up.sh`: Brings up the deployment
* `down.sh`: Takes down the deployment

## Deployments

The deployment directories (`deployments/*`) contain the various deployments which can be made with this repo. The **base deployment** is in the `deployments/tyk` directory. The other directories are **feature deployments**, which extend the base deployment functionality and require the base deployment in order to function correctly.

All of the directories contain `docker-compose.yml`, `bootstrap.sh` and `README.md` files specific to the deployment. They may also contain directories called `data` or `volumes`, which hold the data necessary during bootstrapping or providing as mapped volumes into the container.

## Environment variables

The `docker-compose.yml` files in this repo use Docker environment variables to set OS environment variables for the Dashboard, Gateway and Pump containers. The allows aspects of the Tyk and Docker configration to be overridden without having to make changes to the source configuration files.

As per standard Docker convention, the Docker environment variables are stored in a file called `.env`, which is in the repository root directory.

You can use `.env.example` as a starting point for your `.env` file.

You must set `DASHBOARD_LICENCE` variable with the valid license key you previously got. 
If you are using the MDCB (`mdcb`) deployment, then you need to do the same for `MDCB_LICENCE` variable.


### Notable environment variables are:

| Variable | Description | Required | Default |
| -------- | ----------- | -------- | ------- | 
| DASHBOARD_LICENCE | Sets the licence used by the Tyk Dashboard | Yes | None - **Must** be manually set |
| INSTRUMENTATION_ENABLED | Controls whether the instrumentation feature is enabled (`1`) or disabled (`0`) | No | `0` - Set automatically by the `up.sh` script |
| TRACING_ENABLED | Controls whether the tracing feature is enabled (`true`) or disabled (`false`) | No | `false` - Set automatically by the `up.sh` script |
| GATEWAY_VERSION | Sets the Tyk Gateway container image tag e.g. `v4.0.0` | No | Based on the latest release |
| GATEWAY_LOGLEVEL | Sets the log level for the Tyk Gateway application e.g. `debug`  | No | `info` |
| MDCB_LICENCE | Sets the licence used by the Tyk MDCB | Yes, if using the `mdcb` deployment, otherwise no | None - **Must** be manually set |
| MDCB_USER_API_CREDENTIALS | Sets the credentials used by the Tyk MDCB to authenticate with the Dashboard | Yes, if using the `mdcb` deployment, otherwise no | None - Set automatically by the `bootstrap.sh` script |
| PMP_SPLUNK_META_COLLECTORTOKEN | Sets the credentials used by the Tyk Pump to authenticate with the Splunk collector | Yes, if using the `analytics-splunk` deployment, otherwise no | None - Set automatically by the `bootstrap.sh` script |

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

```
brew install jq
```

Install on Debian/Ubuntu using APT:

```
sudo apt-get install jq
```

See the [JQ installation page](https://stedolan.github.io/jq/download/) for other operating systems.

## Step 2: Map Tyk Demo hostnames to localhost IP

Run the `update-hosts.sh` script to add host entries for the Tyk Dashboard and Portal to `/etc/hosts`:

```
sudo ./scripts/update-hosts.sh
```

The custom hostnames will be used by the Dashboard and Gateway to:

- Differentiate between requests for the Dashboard and Portal
- Identify the API being requested when using custom domains

## Step 3: Add Docker Environment variables

The `tyk/docker-compose.yml` and `tyk2/docker-compose.yml` files use a Docker environment variable to set the dashboard licence. To set this, create a file called `.env` in the root directory of the repo, then set the content of the file as follows, replacing `<YOUR_LICENCE>` with your Dashboard licence:

```
DASHBOARD_LICENCE=<YOUR_LICENCE>
```

In addition to this, some features require entries in the `.env` file. These are set automatically by the `up.sh` file, depending on the deployment parameters.

> :information_source: Your Tyk licence must be valid for at least two Gateways.

## Step 4: Bring the deployment up

To bootstrap the system we will run the `up.sh` script, which will run the necessary `docker-compose` and `bootstrap` commands to start the containers and bootstrap the system. 

```
./up.sh
```

The script displays a message, showing the deployments it will create:

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

```
./up.sh analytics-kibana instrumentation
```

### Bootstrap logging

The bootstrap scripts provide feedback on progress in the `bootstrap.log` file.

## Step 5: Log into the Dashboard

The bootstrap process provides credentials and other useful information in the terminal output. Check this output for the Dashboard credentials.

When you log into the Dashboard, you will find the imported APIs and Policies are now available.

## Step 6 (optional): Import Postman collection

There are Postman collections which compliment the deployments. They contain many example requests which demonstrate Tyk features and functionality in the deployments. If a deployment has a collection it will be in the deployment directory.

The collection for the base *Tyk* Deployment is called `tyk_demo.postman_collection.json`. Import it into [Postman](https://postman.com) to start making requests.

# Resetting

If you want to reset your environment, you need to remove the volumes associated with the container as well as the containers themselves. The `down.sh` script can do this for you.
You don't need to declare which component to remove, since they have already been registered in `.bootstrap/bootstrapped_deployments` by the `up.sh` script. The `down.sh` script will simply remove the deployments listed in that file.

To delete the containers and associated volumes:

```
./down.sh
```

The script displays a message, showing the deployments it intends to remove. For example:

```
Deployments to remove:
  tyk
```

# Redeploying

To redeploy an existing deployment, run the `./down.sh` script followed by the `./up.sh` script:

```
./down.sh && ./up.sh
```

This deletes the containers and volumes associated with the existing deployment, then creates a new deployment based on the `up.sh` command. 

# Appending to an existing deployment

Feature deployments can be added to existing deployment by running the `up.sh` script consecutively. This avoids having to remove the existing deployment with the `down.sh` script.

For example, if `./up.sh` has already been run, there will be a standard `tyk` deployment currently deployed. To add the `sso` deployment to the existing deployment, run:

```
./up.sh sso
```

Note that existing deployments do not need to be specified. The script detects existing deployments and skips them. A message is displayed to confirm the situation:

```
Existing deployments found. Only newly specified deployments will be created.
Deployments to create:
  sso
```

# Check running containers, logs, restart

It is difficult to use the usual docker-compose command in this project since we have various files and project directory. To make commands such as `ps` or `restart` easier to run I have created the script `./docker-compose-command.sh`. You can use it in the same way as you would with docker-compose:
- To check runnng processes: `./docker-compose-command.sh ps`
- To restart the gateway: `./docker-compose-command.sh restart tyk-gateway`
- To tail the logs in the redis container: `./docker-compose-command.sh logs -f tyk-redis`
- To bash into redis container: `./docker-compose-command.sh exec tyk-redis bash`

# Troubleshooting

### Application error when opening the documentation in the portal

You will also see an error in the field that has the base64 encode of the OAS in the catalogue document.
Since the value cannot be base64 *decoded* it means that the base64 *encoding* failed during bootstrap.
One possible reason is that you are using Brew's base64 binary, since Brew's version inserts `\r` to the output rather than just output the base64 encoding as is. You can run `whereis base64` to find out. The expected path should be `/usr/bin/base64`.

### Bootstrap gets stuck with `Request unsuccessful: wanted '200'...` message

It is normal to see this message in the `bootstrap.log` file. It appears when the bootstrap script is waiting for a service to become available before proceeding to the next step. The number of times the message is repeated depends on the performance of your system, as errors are usually due to waiting for a service to start up. So you may find that this message is repeated many times, but will eventually stop and the bootstrap process moves on.

If the message repeats without moving on then the service being tested is experiencing a problem. In this situation you should:

- Check for error messages in the container logs of the service being tested.
- Ensure Docker has sufficient resources to run the deployment. The standard `tyk` deployment should be ok with just 1GB RAM, but it is recommended to make more RAM available (2GB+) when combining multiple deployments together.

These steps will help you diagnose the source of the problem.
