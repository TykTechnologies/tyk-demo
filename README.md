# Tyk Demo

This repo provides an example installation of Tyk. It uses Docker Compose to provide a quick, simple demo of the Tyk stack, this includes the Gateway, the Dashboard and the Portal.

# Getting Started

Note that all commands provided here should be run from the root directory of the repo.

## Step 1: Add your Dashboard licence

The `docker-compose.yml` file uses a Docker environment variable to set the dashboard licence. To set this, create a file called `.env` in the root directory of the repo, then set the content of the file, replacing `<YOUR_LICENCE>` with your Dashboard licence:

```
DASHBOARD_LICENCE=<YOUR_LICENCE>
```

## Step 2: Initialise the Docker containers

Run Docker compose:

```
docker-compose up -d
```

Please note that this command may take a while to complete, as Docker needs to download and provision all of the containers.

## Step 3: Install Tyk Sync

We will use [Tyk Sync](https://tyk.io/docs/advanced-configuration/manage-multiple-environments/tyk-sync/) to synchronise API and Policy data:

```
go install -u github.com/TykTechnologies/tyk-sync
```

## Step 4: Bootstrap the system

First, if you don't have `jq` installed, install it:

```
brew install jq
```

Now we will run the bootstrap script, which will complete the remaining items needed to get started. But before the `bootstrap.sh` file can be run, it must be made executable:

```
chmod +x bootstrap.sh
```

Now you can run the file, passing the admin user's `Tyk Dashboard API Access Credentials` and `Organisation ID` as arguments:

```
./bootstrap.sh
```

## Step 5: Log into the Dashboard

Check the last few lines of output from the `bootstrap.sh` command, these will contain your Dashboard login credentials.

When you log into the Dashboard, you will find the imported APIs and Policies are now available.

# Applications available

The following applications are available once the system is bootstrapped:

- [Tyk Dashboard](http://localhost:3000)
- [Tyk Portal](http://localhost:3000/portal)
- [Tyk Gateway](http://localhost:8080)
- [Kibana](http://localhost:5601)

# Synchronisations of API and Policies

The files in `tyk-sync-data` are API and Policy definitions which are used to store the common APIs and Policies which this demo uses.

There are two scenarios for working with this data:

1. You have made changes and want to commit them so that others can get them
2. You want to get the changes other people have made

## Scenario 1: Committing changes

If you have changed APIs and Policies in your Dashboard, and want to commit these so other people can use them, use the `tyk-sync dump` command:

```
tyk-sync dump -d http://localhost:3000 -s <DASHBOARD_API_ACCESS_CREDENTIALS> -t tyk-sync-data
```

This will update the files in the `tyk-sync-data` directory. You can then commit these files into the repo.

## Scenario 2: Synchronising updates

If you want to get the changes other people have made, use the `tyk-sync sync` command. 

**Warning:** This command is a hard sync which will **delete** any APIs and Policies from your Dashboard that do not exist in the source data.

```
tyk-sync sync -d http://localhost:3000 -s <DASHBOARD_API_ACCESS_CREDENTIALS> -o <ORGANISATION_ID> -p tyk-sync-data
```

# Using Elasticsearch & Kibana

The Tyk Pump is already configured to push data to the Elasticsearch container, so Kibana can visualise this data.

To get started:

1. Create some analytics data by sending requests to an API via the Gateway
1. Log into Kibana via http://localhost:5601/
1. Set up an index pattern for the `tyk_analytics` index:
    - Go to Management -> Index Patterns -> Create Index Pattern
    - Define index pattern: search for `tyk_analytics`, click Next Step
    - Configure settings: select `@timestamp`, click Create Index Pattern
4. Set up a visualisation:
    - Go to Visualize -> Create a visualization
    - Select Line
    - Select `tyk_analytics` as source
    - Select `X-Axis` as bucket type
    - Select `Date Histogram` as aggregation, click Apply icon
5. Try sending more API requests via Gateway to see data appear
6. Bear in mind that by default, graph shows last 15 min data - this can be changed
