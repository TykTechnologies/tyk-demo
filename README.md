# Tyk Demo

This repo provides an example installation of Tyk. It uses Docker Compose to provide a quick, simple deployment, where you can choose what features to include.

The concept is that there is a **standard deployment** of Tyk, which gives you the usual Tyk components: Gateway, Dashboard, Pump, plus the databases Redis and MongoDB. This standard deployment can be extended by including additional **feature deployments** as needed. The feature deployments cover particular scenarios for Tyk, such as:

* Single sign on
* TLS
* Analytics export
* Tracking
* CI/CD
* 2nd Tyk Environment
* Instrumentation

Each feature deployment has its own directory, with the necessary files to deploy the feature and a readme to describe the feature.

There is a focus on simplicity. Docker Compose is used to provision the containers, and bootstrap scripts are used to initialise the environment so that it is ready to use straight away - applying configuration and populating databases.

# Repository Structure

* `deployments/*`: Contains all the deployments available as sub-directories
* `Tyk Demo.postman_collection.json`: A Postman collection of requests which correspond to APIs available in the deployment
* `scripts/*.sh`: Some useful commands encapsulated in scripts
* `up.sh`: Brings up the deployment
* `down.sh`: Takes down the deployment

## Deployments

The deployment directories (`deployments/*`) contain the various deployments which can be made with this repo. The **base deployment** is in the `tyk` directory, which is a standard Tyk deployment. The other directories are **feature deployments**, which extend the **base deployment** functionality. 

All of the directories contain `docker-compose.yml`, `bootstrap.sh` and `README.md` files specific to the deployment. They may also contain directories called `data` or `volumes`, which hold the data necessary during bootstrapping or providing as mapped volumes into the container.

# Getting Started

## Step 1: Install dependencies

### Git Large File Storage

There is a large archive file as part of this repo. [LFS](https://git-lfs.github.com/) has been used to make storage and transfer of this file efficient. 

This **must** be done before this repo is cloned otherwise LFS will not be available to retrieve the large files. Once it is installed you can use git commands normally.

Use brew to install:

```
brew install git-lfs
```

Then initialise Git LFS with this command:

```
git lfs install
```

### JQ

The bootstrap script uses JQ for extracting data from JSON object. Can be installed as follows:

```
brew install jq
```

## Step 2: Clone the repo

The repo must be cloned after Git LFS is initialised. This is due to LFS being needed to transfer the large files in the repo.

```
git clone https://github.com/davegarvey/tyk-pro-docker-demo-extended
```

## Step 3: Add Docker Environment variables

The `docker-compose.yml` file uses a Docker environment variable to set the dashboard licence. To set this, create a file called `.env` in the root directory of the repo, then set the content of the file as follows, replacing `<YOUR_LICENCE>` with your Dashboard licence:

```
DASHBOARD_LICENCE=<YOUR_LICENCE>
```

In addition to this, some features require entries in the `.env` file. These are set automatically by the `bootstrap.sh` files, depending on the deployment.

## Step 4: Deploy the Docker containers

There are multiple compose files for this deployment. This is to give flexibility it terms of what is deployed.

The `docker-compose.yml` is the base compose file, containing Tyk. To deploy the standard deployment of Tyk, run the Docker Compose command:

```
docker-compose up -d
```

You can extend the deployment to demonstrate additional features. To do this, there are additional `docker-compose.yl` files which are stored in the the feature directories and can be included in the deployment. For example, to include the analytics export feature:

```
docker-compose -f docker-compose.yml -f analytics/docker-compose.yml up -d
```

Use additional `-f` flags to include more compose files as needed.

Using `-d` creates the containers in detached mode, running them in the background.

Please note that this command may take a while to complete, as Docker needs to download images and provision the containers.

## Step 4: Make the scripts executable

There are two scripts which can be used to bring up and tear down the deployment: `up.sh` and `down.sh`.

Make these scripts executable:

```
chmod +x up.sh down.sh
```

## Step 5: Bring the deployment up

To bootstrap the system we will run the `up.sh` script, which will run the necessary `docker-compose` and `bootstrap` commands to start the containers and bootstrap the system. 

```
./up.sh
```

This will bring up the standard Tyk deployment, after which you can log into the Dashboard and start using Tyk.

If you want to deploy the feature deployments then you should also bootstrap those systems too. Run the `up.sh` command, passing a parameter of the directory name of the feature to deploy. For example, to bootstrap the analytics feature:

```
./up.sh analytics
```

The feature names are the directory names from the `/deployments` directory.

### Deploying multiple features at the same time

Multiple features can be deployed at the same time by providing multiple parameters e.g.

```
./up.sh analytics instrumentation
```

### Bootstrap logging

During the bootstrap process, check the `bootstrap.log` file for information about the commands being run.

## Step 6: Log into the Dashboard

The `bootstrap.sh` scripts provide credentials and other useful information in the terminal output. Check this output for the Dashboard credentials.

When you log into the Dashboard, you will find the imported APIs and Policies are now available.

## Step 7: Import API requests into Postman

There is a Postman collection built to compliment the API definitions. This lets you start using Tyk features and functionality straight away.

Import the `Tyk Demo.postman_collection.json` into your Postman to start making requests.

# Resetting

The purpose of the `up.sh` script is to enable the environment to be easily set up from scratch. If you want to reset your environment then you need to remove the volumes associated with the container as well as the containers themselves.

To bring down the containers and delete associated volumes:

```
./down.sh
```

If you used deployment parameters when running the `up.sh` script, you should also include them when taking the system down. For example, to bring down the standard Tyk and analytics export deployments:

```
./down.sh analytics
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

This will update the `apis.json` and `policies.json` files in the `deployments/tyk/data/tyk-dashboard` directory. You can then commit these files into the repo.

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