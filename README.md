# Tyk Demo

This repo provides an example installation of Tyk. It uses Docker Compose to provide a quick, simple deployment.

In the [Standard Tyk Deployment](#standard-tyk) you get:

* Tyk Gateway
* Tyk Dashboard
* Tyk Pump
* Redis
* MongoDB
* Local web servers:
  * HTTPbin
  * Swagger Petstore

It's also possible to deploy these complimentary services:

* [Tyk SSO Dashboard & Tyk Identity Broker](#sso-dashboard)
* [Tyk Gateway with TLS configuration](#tls-gateway)
* [Elasticsearch/Kibana](#kibana) (alternative analytics reporting)
* [Zipkin](#zipkin) (tracing)
* [Jenkins](#Jenkins) (CI/CD)
* [2nd Tyk Environment](#tyk-environment-2) (for use with CI/CD)
* [StatsD/Graphite](#graphite) (instrumentation)

# Repository Structure

* `bootstrap-data`: Data used by the bootstrap scripts. Sub-directories group data on a per-application basis.
* `data`: Data used by applications during runtime. Sub-directories group data on a per-application basis.
* `volumes`: Data mounted into containers as volumes. Sub-directories group data on a per-application basis.
* `Tyk Demo.postman_collection.json`: A Postman collection of requests which correspond to APIs available in the deployment.
* `bootstrap/*.sh`: Bootstrap scripts to initialise deployed applications. These are closely aligned with services deployed in the Docker Compose files.
* `docker-compose/*.yml`: Docker Compose deployment definitions. Separate files allow for varied deployments. Complimentary services are defined together within the same file.
* `scripts/*.sh`: Some useful comments encapsulated in scripts.

# Getting Started

Note that all commands provided here should be run from the root directory of the repo.

## Step 1: Add Docker Environment variables

The `docker-compose.yml` file uses a Docker environment variable to set the dashboard licence. To set this, create a file called `.env` in the root directory of the repo, then set the content of the file as follows, replacing `<YOUR_LICENCE>` with your Dashboard licence:

```
DASHBOARD_LICENCE=<YOUR_LICENCE>
```

In addition to this, some features require entries in the `.env` file. Check the [Applications Available](#applications-available) section, if a Docker Environment variable is required for the application, it will be listed in the Setup section for that application. This process is to avoid generating errors in the application logs due to the components trying to utilise a service which has not been deployed. Using Docker Environment variables allows for features to be enable and disabled without having to change the source controlled files.

## Step 2: Initialise the Docker containers

There are multiple compose files for this deployment. This is to give flexibility it terms of what is deployed.

The `docker-compose.yml` is the base compose file, containing Tyk. To bring up the base Tyk installation, run the Docker Compose command:

```
docker-compose up -d
```

To include other services, there are additional compose files which are stored in the `docker-compose` directory and can be included in the deployment. For example, to include Kibana:

```
docker-compose -f docker-compose.yml -f docker-compose/kibana.yml up -d
```

Use additional `-f` flags to include more compose files as needed.

Using `-d` creates the containers in detached mode, running them in the background.

Please note that this command may take a while to complete, as Docker needs to download images and provision the containers.

## Step 3: Install dependencies

### JQ

The bootstrap script uses JQ for extracting data from JSON object. Can be installed as follows:

```
brew install jq
```

## Step 4: Bootstrap the system

Now we will run the bootstrap script, which will complete the remaining items needed to get started. But before the `bootstrap.sh` file can be run, it must be made executable:

```
chmod +x bootstrap.sh
```

Now you can run the file:

```
./bootstrap.sh
```

This will bootstrap the base Tyk system. If you deployed additional services as part of the `docker-compose` command, you should also bootstrap those systems too. Run the corresponding bootstrap file, they are stored in the `bootstrap` directory. For example, to bootstrap Kibana:

```
./bootstrap/kibana.sh
```

**Tip:** The two commands can be run consecutively in a single statement as so:

```
./bootstrap.sh && ./bootstrap/kibana.sh
```

## Step 5: Log into the Dashboard

Check the last few lines of output from the `bootstrap.sh` command, these will contain your Dashboard login credentials.

When you log into the Dashboard, you will find the imported APIs and Policies are now available.

## Step 6: Import API requests into Postman

There is a Postman collection built to compliment the API definitions. This lets you start using Tyk features and functionality straight away.

Import the `Tyk Demo.postman_collection.json` into your Postman to start making requests.

# Resetting

The purpose of the bootstrap scripts is to enable the environment to be easily set up from scratch. If you want to reset your environment then you need to remove the volumes associated with the container as well as the containers themselves.

To bring down the containers and delete associated volumes:

```
docker-compose down -v
```

Or, if you want to retain the existing data then just remove the containers:

```
docker-compose down
```

If you included multiple compose files when bringing the system up, you should also include them when taking the system down. For example, to bring down Tyk and Kibana (and remove volumes):

```
docker-compose -f docker-compose.yml -f docker-compose/kibana.yml down -v
```

# Applications available

The following applications are available once the system is bootstrapped. 

**Note**: All applications require the Standard Tyk deployment.

## Standard Tyk

The standard Tyk deployment, with Dashboard, Gateway, Pump, Redis and MongoDB.

- [Tyk Dashboard](http://localhost:3000)
- [Tyk Portal](http://localhost:3000/portal)
- [Tyk Gateway](http://localhost:8080/basic-open-api/get)

### Requires

* Docker Compose: `docker-compose.yml`
* Bootstrap: `bootstrap.sh`
* Docker environment variable: `DASHBOARD_LICENCE=<YOUR_LICENCE>`

### Scaling the solution

Run the `scripts/add-gateway.sh` script to create a new Gateway instance. It will behave like the existing `tyk-gateway` container as it will use the same configuration. The new Gateway will be mapped on a random port, to avoid collisions.

## SSO Dashboard

Provides an SSO-enabled Tyk Dashboard in conjunction with the Tyk Identity Broker and Okta. It will connect to the same databases as the Standard Tyk deployment.

- [Tyk SSO-enabled Dashboard](http://localhost:3001)

### Requires

* [Standard Tyk](#standard-tyk)
* Docker Compose: `docker-compose/sso.yml`
* Bootstrap: `bootstrap/sso.sh`
* Docker environment variable: `DASHBOARD_LICENCE=<YOUR_LICENCE>`

### SSO process 

**Note:** This example is not very configurable right now, since it relies on a specific Okta setup which is only configurable by the owner of the Okta account (i.e. not you!). Would be good to change this at some point to use a self-contained method which can be managed by anyone. Please feel free to implement such a change an make a pull request. Anyway, here's the SSO we have...

The `dashboard-sso` container is set up to provide a Dashboard using SSO. It works in conjunction with the Identity Broker and Okta to enable this.

If you go to SSO-enabled Dashboard http://localhost:3001 (in a private browser session to avoid sending any pre-existing auth cookies) it will redirect you to the Okta login page, where you can use these credentials to log in:

  - Admin user:
    - Username: `dashboard.admin@example.org`
    - Password: `Abcd1234`
  - Read-only user:
    - Username: `dashboard.readonly@example.org`
    - Password: `Abcd1234`
  - Default user: (lowest permissions)
    - Username: `dashboard.default@example.org`
    - Password: `Abcd1234`

This will redirect back to the Dashboard, using a temporary session created via the Identity Broker and Dashboard SSO API.

Functionality is based on the `division` attribute of the Okta user profile and ID token. The value of which is matched against the `UserGroupMapping` property of the `tyk-dashboard` Identity Broker profile.

## TLS Gateway

This is a TLS-enabled Gateway. It uses a self-signed certificate, so make sure to instruct your HTTP client is ignore certificate verification failure.

- [Tyk TLS Gateway](https://localhost:8081/basic-open-api/get)

### Require

* [Standard Tyk](#standard-tyk)
* Docker Compose `docker-compose/tls.yml`
* Bootstrap `bootstrap/tls.sh`

## Tyk environment 2

This is intended to be used in conjunction with Jenkins. It represents a separate Tyk environment, with an independent Gateway, Dashboard, Pump and databases. We can use Jenkins to automate the deployment of API Definitions and Policies from the default environment to the "e2" environment.

- [Tyk Dashboard environment 2](http://localhost:3002)
- [Tyk Gateway environment 2](http://localhost:8085/basic-open-api/get)

### Requires

* [Standard Tyk](#standard-tyk)
* Docker Compose: `docker-compose/e2.yml`
* Bootstrap: `bootstrap/e2.sh`
* Docker environment variable: `DASHBOARD_LICENCE=<YOUR_LICENCE>`

## Kibana

Demonstrates how analytics data can be push into 3rd party databases and reported on by 3rd party systems.

- [Kibana Dashboard](http://localhost:5601)

### Requires

* [Standard Tyk](#standard-tyk)
* Docker-compose: `docker-compose/kibana.yml`
* Bootstrap: `bootstrap/kibana.sh`

### Analytics data processing

The Tyk Pump deployed with Kibana is already configured to push data to the Elasticsearch container, so Kibana can visualise this data.

The bootstrap process creates an Index Pattern and Visualization which can be used to view API analytics data. It will also stop the original Tyk Pump which is deployed, so that the Elasticsearch-enabled pump can take over.

## Graphite

Graphite demonstrates the [instrumentation feature](https://tyk.io/docs/basic-config-and-security/report-monitor-trigger-events/instrumentation/) of Tyk whereby realtime statistic are pushed from the Dashboard, Gateway and Pump into a StatsD instance. For this example, the statistics can be seen in the [Graphite Dashboard](http://localhost:8060)

* [Graphite Dashboard](http://localhost:8060)

### Requires

* [Standard Tyk](#standard-tyk)
* Docker Compose: `docker-compose/graphite.yml`
* Bootstrap: `bootstrap/graphite.sh`
* Docker environment variable: `INSTRUMENTATION_ENABLED=1`

### Setup

To enable this feature, add `INSTRUMENTATION_ENABLED=1` to your Docker environment file `.env`. This must be done prior to running the `docker-compose` commands.

The StatsD, Carbon and Graphite are all deployed within a single container service called `graphite`.

### Usage

Open the [Graphite Dashboard](http://localhost:8060]). Explore the 'Metrics' tree, and click on items you are interested in seeing, this will add them to the graph. Most of the Tyk items are in `stats` and `stats_counts`.  Try sending some requests through the Gateway to generate data.

## Zipkin

Zipkin can demonstrate open tracing. It has a [Dashboard](http://localhost:9411) you can use to view traces.

It has been configured to use in-memory storage, so will not retain data once the contain is restarted/removed.

- [Zipkin Dashboard](http://localhost:9411)

### Requires

* [Standard Tyk](#standard-tyk)
* Docker Compose: `docker-compose/zipkin.yml`
* Bootstrap: `bootstrap/zipkin.sh`
* Docker environment variable: `TRACING_ENABLED=true`

### Setup

To enable this feature, add `TRACING_ENABLED=true` to your Docker environment file `.env`. This must be done prior to running the `docker-compose` commands.

### Usage 

To use Zipkin, open the [Zipkin Dashboard](http://localhost:9411) in a browser and click the magnifying glass icon, this will conduct a search for all available traces. You can add filters for the trace search. There should be at least one trace entry for the "Basic Open API", which is made during the bootstrap process. If you don't see any data, try changing the duration filter to longer period.

## Jenkins

Jenkins is used to provide an automated way of pushing API Definitions and Policies to different Tyk environments. It uses the `tyk-sync` CLI tool and a Github repository to achieve this.

- [Jenkins Dashboard](http://localhost:8070)

### Requires

* [Standard Tyk](#standard-tyk)
* Docker Compose: `docker-compose/jenkins.yml`
* Bootstrap: `bootstrap/jenkins.sh`

### Setup

Setting up Jenkins is a manual process:

1. Browse to [Jenkins web UI](http://localhost:8070)
2. Use the Jenkins admin credentials shown in the bootstrap output to log in
3. Install suggested plugins
4. Add credentials: (these are needed by `tyk-sync` to push data into the e2 Dashboard)
  - Kind: Secret text
  - Scope: Global (this is just a PoC...)
  - Secret: The e2 Dashboard API credentials, shown in `Creating Dashboard user for environment 2` section of the bootstrap output
  - ID: `tyk-dash-secret`
  - Description: `Tyk Dashboard Secret`
5. Create a new job:
  - Name: `APIs and Policies`
  - Type: Multibranch Pipeline
  - Branch Source: Github
  - Branch Source Credentials: Your Github credentials (to avoid using anonymous GitHub API usage, which is very restrictive)
  - Branch Source -> Repository HTTPS URL: Github URL for this repository
  - Build Configuration -> Script Path: `data/jenkins/Jenkinsfile`

Ideally, this will be automated in the future.

### Usage

After the setup process is complete, the CI/CD functionality can be demonstrated as follows:

1. Log into the [e2 Dashboard](http://localhost:3002) (using credentials shown in bootstrap output, and a private browser session to avoid invalidating your session cookie for the default Dashboard)
2. You will see that there are no API Definitions or Policies
3. Build the `APIs and Polcies` job in Jenkins
4. Check the e2 Dashboard again, you will now see that it has the same API Definitions and Policies as the default Dashboard.
5. Check that the e2 Gateway can proxy requests for these APIs by making a request to the [Basic Open API](http://localhost:8085/basic-open-api)

### Jenkins CLI

The Jenkins CLI is set up as part of the bootstrap process. This may be useful for importing job data etc. See [the Jenkins wiki](https://wiki.jenkins.io/display/JENKINS/Jenkins+CLI) and [Jenkins commands](http://localhost:8070/cli/) for reference.

Commands can be sent to the CLI via docker. Here's an example which gets the 'APIs and Policies' Job we created, but replace `f284436d222a4d73841ae92ebc5928e8` with your Jenkins admin password:

```
docker-compose exec jenkins java -jar /var/jenkins_home/jenkins-cli.jar -s http://localhost:8080/ -auth admin:f284436d222a4d73841ae92ebc5928e8 -webSocket get-job 'APIs and Policies'
```

# Working with APIs and Policies

There are two scenarios for working with this data:

1. You have made changes and want to commit them so that others can get them
2. You want to get the changes other people have made

## Scenario 1: Committing changes

If you have changed APIs and Policies in your Dashboard, and want to commit these so other people can use them, use the `export.sh` script.

Run from the repo root directory, as so:

```
./scripts/export.sh
```

This will update the `apis.json` and `policies.json` files in the `bootstrap-data/tyk-dashboard/` directory. You can then commit these files into the repo.

If you have also made changes to the Postman collection then export it and overwrite the `Tyk Demo.postman_collection.json` and commit that too.

## Scenario 2: Synchronising updates

If you want to get the changes other people have made, first pull from the repo, then use the `import.sh` script.

Run from the repo root directory, as so:

```
./scripts/import.sh
```

## Why not use Tyk Sync?

The Tyk Sync binary is not always kept up-to-date with the latest changes in API and Policy object, which unfortunately means that the data it exports may be missing information. This also means that when this data is imported into the system, that the objects created will also be missing this data.

So, until the Tyk Sync project is updated and released in-line with the Tyk Dashboard project, it is safer to manually handle data import and export directly with the Dashboard API.
