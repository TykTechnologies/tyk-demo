This file serves as guidance to those wishing to contribute/extend this repo.

You can use the Tyk deployment `deployments/tyk` as a reference implementation.

# Deployments

Deployments are the discrete elements of this repo which enable users to decide what to deploy.

Deployments should be contained within their own directory within the `deployments` directory. The deployment directory name should be refer to the purpose of the deployment i.e. the functionality that can be demonstrated by the deployment.

## Files

Deployments must contain the following files:

* `docker-compose.yml`: A Docker Compose file which specifies the services to deploy
* `bootstrap.sh`: A bootstrap script which prepares the deployment so that it's ready to use
* `readme.md`: A readme file which describes how the deployment can be used

## Directories

Deployments can also contain directories, if needed:

* `volumes`: Contains data for use as volumes referenced by the `docker-compose.yml` file
* `data`: Contains data for general use e.g. during bootstrapping

Both the `volumes` and `data` directories should contain sub-directories named after services, using the service name from the `docker-compose.yml` file. 

For example, in the `tyk` deployment, the Tyk Gateway's (`tyk-gateway`) configuration file (`tyk.conf`) is mapped as a volume, so has the path `volumes/tyk-gateway/tyk.conf`.

## Docker Compose

The deployment's Docker Compose file must be named `docker-compose.yml`, and contain the services required by the deployment.

This file will be used as a parameter, alongside the base deployment's `deployments/tyk/docker-compose.yml`. This means that it only needs to contain services beyond those in the base deployment i.e. you do not need to specify a Dashboard, Gateway pump etc, as these are already in the base deployment.

## Bootstrap Script

The bootstrapping process prepares the deployment for use, so that they can immediately be demonstrated.

When creating the bootstrap for a deployment, follow these conventions:

* At the start of the bootstrap process:
  * Reference the `scripts/common.sh` script, as this contains useful bootstrap functions e.g. `source scripts/common.sh`
  * Set the `deployment` variable, as this is used in the `common.sh` bootstrap functions e.g. `deployment="My Deployment Name"`
  * Call the `log_start_deployment` function, to log the start of the deployment
* At the start of each step:
  * Call the `log_message` function to log what is happening e.g. `log_message "Updating configuration"`
* During each step:
  * Call the `log_message` function to log any useful information, prefixing messages with two spaces to indent them e.g. `log_message "  Useful indented message"`
  * Call the `bootstrap_progress` function to provide progress feedback during long-running steps
* At the end of each step:
  * Call the `bootstrap_progress` function to provide progress feedback
  * Call either the `log_ok`, `log_json_result` or `log_http_result` function, as appropriate,to log the end of the step
* At the end of the bootstrap process:
  * Call the `log_end_deployment` function, to log the end of the deployment
  * Echo relevant information about the deployment

### Displaying information

At the end of the bootstrap process, display relevant information about the deployment that the user will find useful. This may be URLs of services, usernames, passwords etc.

Follow these rules when displaying the deployment output:

* Start with the echo command `echo -e "\033[2K`
* Put the deployment name prefixed with `▼ ` e.g. `▼ Deployment name`
* For each service you want to display:
  * In column 3, put the service name, prefixed with `▽ ` e.g. `  ▽ Service name`
  * For each piece of information you want to display:
    * Display the information as a colon separated label and value, aligned so that the colon is on column 20 e.g. `       Useful info : $variable_data`
* Remember to end the string on the last line e.g. `"`

Here is an example:

```
echo -e "\033[2K
▼ Deployment name
  ▽ Service name
       Useful info : $variable_data
        Other info : hardcoded data
  ▽ Another service
         More data : $another_variable"
```

Following these rules will allow the displayed data to be aligned uniformly with other bootstrap output.

For more examples, check the `bootstrap.sh` files in other deployments.

## Readme

The deployment's `readme.md` should contain:

* A description of the deployment
* Example command to deploy the deployment
* Useful information on the usage of the deployment

# Scripts

These scripts are available in the `scripts` directory:

* `add-gateway.sh`: Creates a new Tyk Gateway container, using the same configuration as the base Tyk deployment Gateway
* `common.sh`: Contains functions useful for bootstrap scripts
* `export.sh`: Uses the Dashboard API to export API and Policy definitions, overwriting data used to bootstrap the base Tyk deployment
* `import.sh`: Uses the Dashboard Admin API to import API and Policy definitions, using data used to bootstrap the base Tyk deployment

# Working with API and Policy data

There are two scenarios for working with this data:

1. You have made changes and want to commit them so that others can get them
2. You want to get the changes other people have made

## Scenario 1: Committing changes

If you have changed APIs and Policies in your Dashboard, and want to commit these so other people can use them, use the export script.

Run from the repo root directory, as so:

```
./scripts/export.sh
```

This will update the `apis.json` and `policies.json` files in the `deployments/tyk/data/tyk-dashboard` directory. You can then commit these files into the repo.

When adding functionality to this repo, please also add requests to the Postman collection to demonstrate the functionality, including a description and tests necessary to validate the response. Once the requests and tests are added, export the collection and overwrite the `tyk_demo.postman_collection.json` file, which can then be committed too.

## Scenario 2: Synchronising updates

The simplest and best-practice approach to simple bring the environment down, pull the repo then bring it back up again. The up script includes an API and Policy import step.

If you want to get the changes other people have made, first pull from the repo, then use the import script.

Run from the repo root directory, as so:

```
./scripts/import.sh
```


## Why not use Tyk Sync?

The Tyk Sync binary is not always kept up-to-date with the latest changes in API and Policy object, which unfortunately means that the data it exports may be missing information. This also means that when this data is imported into the system, that the objects created will also be missing this data.

So, until the Tyk Sync project is updated and released in-line with the Tyk Dashboard project, it is safer to manually handle data import and export directly with the Dashboard API.