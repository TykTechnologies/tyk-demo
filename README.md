# Tyk Demo

This repo provides an example installation of Tyk. It uses Docker Compose to provide a quick, simple deployment, where you can choose what features to include.

It has been built to enable the sharing of knowledge and combining of effort amongst client-facing technical Tyk folks.

See the [Developer Guide](developer-guide.md) for information on how to contribute to and extend this repository.

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


## Repository Structure

* `deployments/*`: Contains all the deployments available as sub-directories
* `test.postman_environment.json`: Set of environment variables, for use when running tests with a Newman container within a Docker deployment
* `scripts/*.sh`: Some useful commands encapsulated in scripts
* `up.sh`: Brings up the deployment
* `down.sh`: Takes down the deployment

## Deployments

The deployment directories (`deployments/*`) contain the various deployments which can be made with this repo. The **base deployment** is in the `deployments/tyk` directory. The other directories are **feature deployments**, which extend the base deployment functionality and require the base deployment in order to function correctly.

All of the directories contain `docker-compose.yml`, `bootstrap.sh` and `README.md` files specific to the deployment. They may also contain directories called `data` or `volumes`, which hold the data necessary during bootstrapping or providing as mapped volumes into the container.

# Getting Started

## Step 1: Install dependencies

### Docker

Docker is required. Follow the [Docker installation guide](https://docs.docker.com/get-docker/) for your platform.

Docker Compose is required. If you're installing on Mac or Windows, then Docker Compose is already included as part of the base Docker install, so you don't need to do anything else. For Linux, follow the [Docker Compose installation guide](https://docs.docker.com/compose/install/).

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

This will bring up the standard Tyk deployment, after which you can log into the Dashboard and start using Tyk.

### Deploying a feature

If you want to deploy features, run the `up.sh` command, passing a parameter of the directory name of the feature to deploy. For example, to deploy both the standard Tyk deployment and the `analytics` deployment:

```
./up.sh analytics
```

The feature names are the directory names from the `deployments` directory.

### Deploying multiple features at the same time

Multiple features can be deployed at the same time by providing multiple feature parameters. For example, to deploy `analytics` and `instrumentation`:

```
./up.sh analytics instrumentation
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

If you want to reset your environment then you need to remove the volumes associated with the container as well as the containers themselves. The `down.sh` script can do this for you.
You do not need to declare which component to remove since the `up.sh` has already registered them in `.bootstrap/bootstrapped_deployments` so the `down.sh` will just read it and stop all those services.

To bring down the containers and delete associated volumes:

```
./down.sh
```

# Redeploying

The `up.sh` script is not intended to be run consecutively without running `down.sh` in between. The reason for this is that the `up.sh` script assumes that the system will not contain any data, so it attempts to bootstrap the system by creating data. This means that running the script consecutively will likely generate errors and duplicate data.

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

- check for error messages in the container logs of the service being tested
- ensure Docker has sufficient resources to run the deployment (particularly when combining multiple deployments together)

These steps will help you diagnose the source of the problem.
