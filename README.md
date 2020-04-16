# This demo is NOT designed for production use or performance testing
Tyk API Gateway is fully on-premise solution, which include gateway, dashboard and analytics processing pipeline.
This demo will run Tyk On-premise on your machine, which contains 5 containers: Tyk Gateway, Tyk Dashboard, Tyk Pump, Redis and Mongodb.
This repo great for proof of concept and demo purpose, but if you want test performance, you need to move each component to separate machine, following our documentation https://tyk.io/docs/.


# Tyk Pro Demo using Docker Swarm

Please refer to [docker-swarm.md](docker-swarm.md) for detailed instructions on running this simple deployment on the Docker Swarm with Tyk cluster. Note that in order to have more than one functional gateway node a corresponding license is required.

# Tyk Pro Demo using Docker

This compose file is designed to provide a quick, simple demo of the Tyk stack, this includes the gateway, the dashboard and the portal.

## Step 1: Map hostnames to IP addresses

Set up your `/etc/hosts` file to include the IP of your docker daemon:

```
127.0.0.1 www.tyk-portal-test.com
127.0.0.1 www.tyk-test.com
```

Note that the IP may be different depending on your installation, Windows users may find it running on `10.x.x.x`, it is important the URL stays the same because our `setup.sh` assumes this is the one you are using.

## Step 2: Add your dashboard license

Open the `tyk_analytics.conf` file in the `confs/` folder and add your license string to the `"license_key": ""` section.

## Step 3: Initialise the Docker containers

Run docker compose:

```
docker-compose -f docker-compose.yml -f docker-local.yml up
```

Please note that this command may take a while to complete, as Docker needs to download and provision all of the containers.

This will run in non-daemonised mode so you can see all the output. For the next step, once this step is complete, open a new shell:

## Step 4: Bootstrap the Tyk installation

Bootstrap the instance:

Open your browser to http://www.tyk-test.com:3000.  You will be presented with the Bootstrap UI to create your first organisation and admin user.

Note, if you run into DNS issues with `www.tyk-test.com` while trying to bootstrap through the GUI, you will need to set the `host_config.hostname` value in `tyk_analytics.conf` to the public IP of your Docker daemon or simply use `localhost`



# Licencing

The docker compose file uses a Docker environment variable to set the dashboard licence. To implement this, create a file called `.env` in the root of the repo, then set the content of the file to be:

```
DASHBOARD_LICENCE=<YOUR_LICENCE>
```

Replacing `<YOUR_LICENCE>` with your Dashboard licence.

# Syncing Data

Use [Tyk Sync](https://tyk.io/docs/advanced-configuration/manage-multiple-environments/tyk-sync/) to synchronise data. Install it locally and target your containerised environment.

Data for Tyk Sync should be stored in the `tyk-sync-data` directory. This directory should be the target for your `tyk-sync` commands, so either run the command from that directory or use the `-t` flag to specify the location.

When you make changes to the environment which you want everyone else to benefit from, dump the data and commit it to the repo.

## Extracting data

```
tyk-sync dump -d http://localhost:3000 -s <YOUR_API_KEY>
```

## Syncing data

When syncing data with your local Dashboard, override the org id so that the data ends up available in your particular org. This is because other user's org ids will not be the same as yours.

**Important Note**: This command will fully sync your API definitions and policies, which means that it will **delete** data in the Dashboard which is not in the source data directory.

```
tyk-sync sync -d http://localhost:3000 -s <YOUR_API_KEY> -o <YOUR_ORG_ID> -p <YOUR_TYK_SYNC_DATA_PATH>
```