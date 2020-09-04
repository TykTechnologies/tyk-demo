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

Optionally, a Postman collection can be provided, containing deployment-specific requests. This file should be named `tyk_demo_<DEPLOYMENT_NAME>.postman_collection.json` e.g. for the `mdcb` deployment, the file is called `tyk_demo_mdcb.postman_collection.json`.

## Directories

Deployments can also contain directories, if needed:

* `volumes`: Contains data for use as volumes referenced by the `docker-compose.yml` file
* `data`: Contains data for general use e.g. during bootstrapping
* `scripts`: Contains scripts related to bootstrapping or using the deployment

Both the `volumes` and `data` directories should contain sub-directories named after services, using the service name from the `docker-compose.yml` file. 

For example, in the `tyk` deployment, the Tyk Gateway's (`tyk-gateway`) configuration file (`tyk.conf`) is mapped as a volume, so has the path `volumes/tyk-gateway/tyk.conf`.

## Docker Compose

The deployment's Docker Compose file must be named `docker-compose.yml`, and contain the services required by the deployment.

This file will be used as a parameter, alongside the base deployment's `deployments/tyk/docker-compose.yml`. This means that it only needs to contain services beyond those in the base deployment i.e. you do not need to specify a Dashboard, Gateway pump etc, as these are already in the base deployment.

## Docker environment variables

If the deployment makes use of Docker environment variables which would have adverse effects on the system if set incorrectly, use the `up.sh` script to verify the values and correct them as needed.

The `scripts/common.sh` provides the `set_docker_environment_value` function to set Docker environment variables to desired values. Check the `up.sh` script for implementations for the `tracing` and `instrumentation` deployments.

## Bootstrap Script

The bootstrapping process prepares the deployment for use, so that they can immediately be demonstrated.

When creating the bootstrap for a deployment, follow these conventions:

* At the start of the bootstrap script:
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
* At the end of the bootstrap script:
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
    * Display the information as a colon separated label and value, aligned so that the colon is on column 25 e.g. `            Useful info : $variable_data`
  * If you need to embed additional information you can use the small triangle `▾` and `▿` characters
* Remember to end the last line with a string terminator e.g. `"`

Here is an example:

```
echo -e "\033[2K
▼ Deployment name
  ▽ Service name
            Useful info : $variable_data
             Other info : hardcoded data
    ▾ Embedded object
         With some info : $variable_data_2
  ▽ Another service
              More data : $another_variable"
```

Following these rules will allow the displayed data to be aligned uniformly with other bootstrap output.

For more examples, check the `bootstrap.sh` files in other deployments.

### Context data directory

The `.context-data` directory is used to store data generated during bootstrap scripts so that other scripts can access and use that data. This is particularly important for dynamic data, such as the ids of data added via the Dashboard API.

For example, the base Tyk deployment bootstrap script (`deployments/tyk/bootstrap.sh`) writes the Dashboard API credentials to `.context-data/dashboard-user-api-credentials`, which can then be read by other scripts. When the SSO deployment is used, its bootstrap script (`deployments/sso/bootstrap.sh`) reads the content of the file so that it can access the Dashboard API.

## Readme

The deployment's `readme.md` should contain:

* A description of the deployment
* Example command to deploy the deployment
* Useful information on the usage of the deployment

# Scripts

The `up.sh` and `down.sh` scripts bring the deployments up and down.

Both scripts accept arguments for the deployments to include. The base Tyk deployment is hard-coded into the scripts, so there is no need to pass `tyk` as an argument.

The up script has three main purposes:

1. Ensure the Docker environment variables are set correctly based on the deployment arguments
2. Run a Docker Compose command referencing the base Tyk deployment (`deployments/tyk/docker-compose.yml`) and any deployments provided as arguments
3. Run the bootstrap script for the base Tyk deployment (`deployments/tyk/bootstrap.sh`) and any deployments provided as arguments

The down script's only purpose is to run a docker-compose command to bring the deployments down. The docker-compose command include the `-v` switch, which removes the volumes, ensuring that no data is persisted.

## Utilities

These utility scripts are available in the `scripts` directory:

* `add-gateway.sh`: Creates a new Tyk Gateway container, using the same configuration as the base Tyk deployment Gateway
* `common.sh`: Contains functions useful for bootstrap scripts
* `export.sh`: Uses the Dashboard API to export API and Policy definitions, overwriting data used to bootstrap the base Tyk deployment
* `import.sh`: Uses the Dashboard Admin API to import API and Policy definitions, using data used to bootstrap the base Tyk deployment
* `test.sh`: Uses a Newman container to run the Postman collection tests

# Working with API and Policy data

There are two scenarios for working with this data:

1. You have made changes and want to commit them so that others can get them
2. You want to get the changes other people have made

## Scenario 1: Committing changes

Before you commit anything to the repo, you must check that **all tests are working correctly**. Run the `./scripts/test.sh`, if any tests fail then please resolve the issue before committing.

If you have changed APIs and Policies in your Dashboard, and want to commit these so other people can use them, use the export script.

To export the data, run the export script from the repo root directory, as so:

```
./scripts/export.sh
```

This will update the `apis.json` and `policies.json` files in the `deployments/tyk/data/tyk-dashboard` directory. You can then commit these files into the repo.

When adding functionality to this repo, please also add requests to the Postman collection to demonstrate the functionality, including a description and tests necessary to validate the response. Once the requests and tests are added, export the collection and overwrite the `tyk_demo.postman_collection.json` file, which can then be committed too.

## Scenario 2: Synchronising updates

The simplest and best-practice approach is to simply bring the environment down, pull the repo then bring it back up again. The `up.sh` script includes an API and Policy import step, so all latest data will be imported:

```
./down.sh
./up.sh
```

Alternatively, you can import data into and existing deployment by first pulling the repo, then using the import script:

```
./scripts/import.sh
```

## Why not use Tyk Sync?

The Tyk Sync binary is not always kept up-to-date with the latest changes in API and Policy object, which unfortunately means that the data it exports may be missing information. This also means that when this data is imported into the system, that the objects created will also be missing this data. This issue will be addressed in a future release of Tyk Sync. In the mean time, it is safer to manually handle data import and export directly with the Dashboard API.
