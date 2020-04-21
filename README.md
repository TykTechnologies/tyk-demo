# Tyk Demo

This repo provides an example installation of Tyk. It uses Docker Compose to provide a quick, simple demo of the Tyk stack, this includes the Gateway, the Dashboard and the Portal.

# Getting Started

Note that all commands provided here should be run from the root directory of the repo.

## Step 1: Add your Dashboard licence

The `docker-compose.yml` file uses a Docker environment variable to set the dashboard licence. To set this, create a file called `.env` in the root directory of the repo, then set the content of the file as follows, replacing `<YOUR_LICENCE>` with your Dashboard licence:

```
DASHBOARD_LICENCE=<YOUR_LICENCE>
```

## Step 2: Initialise the Docker containers

Run Docker compose:

```
docker-compose up -d
```

Please note that this command may take a while to complete, as Docker needs to download images and provision the containers.

## Step 3: Install dependencies

### Tyk Sync

[Tyk Sync](https://tyk.io/docs/advanced-configuration/manage-multiple-environments/tyk-sync/) is used to synchronise API and Policy data. Install it as follows:

```
go install -u github.com/TykTechnologies/tyk-sync
```

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
- [Tyk Gateway](http://localhost:8080/bootstrap-api/get)
- [Kibana](http://localhost:5601)

# Synchronisations of API and Policies

The files in `tyk-sync-data` are API and Policy definitions which are used to store the common APIs and Policies which this demo uses.

There are two scenarios for working with this data:

1. You have made changes and want to commit them so that others can get them
2. You want to get the changes other people have made

## Scenario 1: Committing changes

If you have changed APIs and Policies in your Dashboard, and want to commit these so other people can use them, use the `dump.sh` script, which is pre-configured to call the `tyk-sync dump` command using you local `.organisation-id` value:

```
./dump.sh
```

This will update the files in the `tyk-sync-data` directory. You can then commit these files into the repo.

## Scenario 2: Synchronising updates

If you want to get the changes other people have made, use the `sync.sh` script, which calls the `tyk-sync sync` command using you local `.organisation-id` and `.dashboard-user-api-credentials` files.

To get the latest updates, you should pull from the remote repo first.

**Warning:** This command is a hard sync which will **delete** any APIs and Policies from your Dashboard that do not exist in the source data.

```
./sync.sh
```

# Using Elasticsearch & Kibana

The Tyk Pump is already configured to push data to the Elasticsearch container, so Kibana can visualise this data.

The bootstrap process creates an Index Pattern and Visualization which can be used to view API analytics data.

Go to http://localhost:5601/app/kibana to access Kibana and view the visualisation.

# SSO Dashboard

The `dashboard-sso` container is set up to provide a Dashboard using SSO. It works in conjunction with the Identity Broker and Okta to enable this.

If you go to http://localhost:3001 it will redirect you to the Okta login page, where you can use these credentials to log in:

Username: `dashboard.admin@example.org`
Password: `Abcd1234`

This will redirect back to the Dashboard, using a temporary session created via the Identity Broker and Dashboard SSO API.
