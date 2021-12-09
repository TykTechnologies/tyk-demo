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

### Data Groups

Numbered directories within the `/data/tyk-dashboard` directory allow the data files to be grouped and processed in a segmented manner. This approach simplifies bootstrapping of separate organisations and recording resulting data.

The bootstrap and export scripts are written to iterate through these directories, processing them in numerical order.
## Docker Compose

The deployment's Docker Compose file must be named `docker-compose.yml`, and contain the services required by the deployment.

This file will be used as a parameter, alongside the base deployment's `deployments/tyk/docker-compose.yml`. This means that it only needs to contain services beyond those in the base deployment i.e. you do not need to specify a Dashboard, Gateway pump etc, as these are already in the base deployment.

## Docker Environment Variables

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
  * Call either the `log_ok`, `log_json_result` or `log_http_result` function, as appropriate, to log the end of the step
* At the end of the bootstrap script:
  * Call the `log_end_deployment` function, to log the end of the deployment
  * Echo relevant information about the deployment (see Displaying Information, below)

### Displaying Information

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

### Context Data Directory

The `.context-data` directory is used to store data generated during bootstrap scripts so that other scripts can access and use that data. This is particularly important for dynamic data, such as the ids of data added via the Dashboard API. The `scripts/common.sh` script contains functions to read (`get_context_data`) and write (`set_context_data`) this data.

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
* `test.sh`: Uses a Newman container to run the Postman collection tests
* `update-hosts.sh`: Adds the necessary hosts to the `/etc/hosts` file

Note that there is no *import* script, as the `up.sh` script essentially imports the data when bootstrapping the deployment.

# Working with APIs, Policies and Postman Data

There are two scenarios for working with this data:

1. You have made changes and want to commit them so that others can get them
2. You want to get the changes other people have made

## Scenario 1: Committing Changes to Remote

In this scenario you have made updates to the repo which you want to commit back to master.

Before making a pull request, please check that **all tests are working correctly**. Run the `./scripts/test.sh`, if any tests fail then please resolve.

If you have made changes to APIs or Policies, you can run the export script to update the version controlled data files:

```
./scripts/export.sh
```

This will update the `apis.json` and `policies.json` files in the `deployments/tyk/data/tyk-dashboard` path. Other types of data will need to be exported manually, or update the `export.sh` script to include your data. Please ensure that any necessary data is automatically added to the deployment when the `up.sh` script is run.

When adding functionality to this repo, please also add requests to the Postman collection to demonstrate the functionality. Include a description and enough tests to validate the response. Tests are especially important to avoid regressions, so please add them. Export the collection and overwrite the `tyk_demo.postman_collection.json` file in the deployment directory.

## Scenario 2: Synchronising Updates from Remote

The simplest and best-practice approach is to simply bring the environment down, pull the repo then bring it back up again. The `up.sh` script includes commands to import APIs, Policies and other data, so all latest data will be imported:

```
./down.sh
git pull
./up.sh
```

# Postman Scripts

## Tyk Postman Library

The Tyk Postman Library provides functions for simplified access to the Tyk Gateway, Dashboard and Dashboard Admin APIs.

The library simplifies Tyk API access by wrapping the Postman HTTP request method (`pm.sendRequest`) and automatically setting the necessary host, method, path, headers and body. All the developer must do is provide the necessary parameter values, callback function (if needed) and Postman context:
- The parameters vary depending on the function e.g. the id of an object to retrieve, or the body data to create an object.
- The callback function can be used to perform further operations once the request is completed. The function is passed straight to Postman's `pm.sendRequest` function.
- The Postman context is needed, as it is not accessible by the script directly, so must be passed into the function at runtime.

The library is stored in the root of the Postman collection as a pre-request script. To view it, click the *Tyk Demo* tree root element, then click on *Pre-request Script*. Storing the script here makes it available to all requests within the collection.

Functions are namespaced, by API and object e.g. `tyk.dashboardAdminApi.organisations`. Within the namespaces are the functions which represent the different endpoints for that API and object. For example, the `create` function within `tyk.dashboardAdminApi.organisations` represents a `POST` request to the `/admin/organisations` endpoint:

```javascript
tyk = {
    dashboardAdminApi: {
        organisations: {
            create: function (organisation, callback, pm) {
                pm.sendRequest(
                    {
                        url: "http://" + pm.variables.get("tyk-dashboard.host") + "/admin/organisations",
                        method: "POST",
                        header: "admin-auth: " + pm.variables.get("tyk-dashboard.admin-api-key"),
                        body: organisation
                    }, 
                    callback
                );   
            }
        }
    }
}
```

Postman variables are used to retrieve some data, where it's possible and appropriate to do so, such as hostnames and API keys.

### Use in Postman Scripts

Some requests benefit from or require access to Tyk data. The Tyk Postman Library can be used to perform the necessary interactions with the Tyk API.

#### Creating Data

The *Tyk Demo > General Tests > Dashboard API > Users > Get a User* request creates a temporary user in the *Pre-request Script* so that the request can retrieve it:

```javascript
tyk.dashboardAdminApi.users.create(
    JSON.stringify({
        first_name: pm.variables.get("user-first-name"),
        last_name: pm.variables.get("user-last-name"),
        email_address: pm.variables.get("user-email-address"),
        org_id: "5e9d9544a1dcd60001d0ed20",
        active: true,
        password: "3LEsHO1jv1dt9Xgf",
        user_permissions: {
            IsAdmin: "admin",
            ResetPassword: "admin"
        }
    }),
    (error, response) => { 
        pm.expect(response.code).to.eql(200);
        // user id needed for request, and to delete after tests
        pm.variables.set("user-id", response.json().Meta.id);
        pm.variables.set("user-api-key", response.json().Meta.access_key);
    },
    pm
);
```

Notice that the Postman variables `user-id` and `user-api-key` are used to temporarily store the data. This is so it can be used later on, in the request and tests.

#### Deleting Data

Any temporary data created should be deleted once it's no longer required. This prevents the Tyk deployment from filling up with temporary data when running requests in the Postman collection. Use the Tyk Postman Library's `delete` functions to do this. In this example, the user is deleted at the end of the *Tests* script:

```javascript
tyk.dashboardApi.users.delete(
    pm.variables.get("user-id"), 
    (error, response) => {
        pm.expect(response.code).to.eq(200);
        tyk.dashboardApi.tools.apiKey.delete(pm);
    },
    pm
);
```

#### Reading Data

The *Tyk Demo > General Tests > Dashboard Admin API > Organisations > Create an Organisation* request uses the `Meta` JSON value returned in the response to retreive the organisation and then validate the value of its `owner_name` property:

```javascript
pm.test("Organisation is created", function () {
    tyk.dashboardAdminApi.organisations.get(
        pm.response.json().Meta,
        (error, response) => { 
            pm.expect(response.code).to.eql(200);
            pm.expect(response.json().owner_name).to.eql("Create an Organisation Test");
        },
        pm
    );
});
```

#### Dashboard API Keys

The Dashboard API requires authentication using a Dashboard User API key. These keys are randomly generated when a user is created, so cannot be defined in advance like the Dashboard Admin API key. 

To provide the Dashboard API requests with a key, there are two functions which will generate and delete a key (and the related user). When the key is generated it is automatically stored in the `tyk-dashboard.api-key` Postman variable so that it can be used in the requests.

To facilitate the generation of Dashboard API Keys for all Dashboard API requests, the *Tyk Demo > General Tests > Dashboard API* tree element has a pre-request script which generates a Dashboard API key:

```javascript
tyk.dashboardApi.tools.apiKey.create(pm);
```

This key can then be used by all the scripts within the *Dashboard API* branch, such as *Users > Get a User*, by referencing the Postman variable `{{tyk-dashboard.api-key}}` for the value of the `Authorization` header. 

Once the tests are finished, the `delete` function can be called to remove the key from the database:

```javascript
tyk.dashboardApi.tools.apiKey.delete(pm);
```

## Testing Responses

The Tyk Demo Postman collection contains many requests, each of which demonstrate a particular piece of functionality. Testing the responses generated by these requests provides validation that the desired result was achieved.

There are many ways in which the response can be validated, here are some examples.

### HTTP Response Status Code

The HTTP Status Code returned by the response e.g. 200:

```javascript
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});
```

### Response Body Data

The body data returned by the response, depending if it's relevant e.g. "status" is "ok":

```javascript
pm.test("Status is ok", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.status).to.eql("ok");
});
```

### Response Header Data

The header data returned by the response, depending if it's relevant e.g. "New-Header" is present:

```javascript
pm.test("'New-Header' header is present", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.headers['New-Header']).to.eql("new-header-value");
});
```

### Additional Requests

Making additional requests can help validate a feature e.g. rate limiting:

```javascript
pm.test("Status code is 429", function () {
    var rateLimitRequest = {
        url: 'http://' + tykGatewayHost + '/basic-protected-api/get',
        method: 'GET',
        header: 'Authorization:' + keyId
    };
    pm.sendRequest(rateLimitRequest, function (err, response) {
        pm.expect(response.code).to.eql(200);
        pm.sendRequest(rateLimitRequest, function (err, response) {
            pm.expect(response.code).to.eql(200);
            pm.sendRequest(rateLimitRequest, function (err, response) {
                pm.expect(response.code).to.eql(429);
            });
        });
    });
});
```
## Dynamic Variables

Postman's dynamic variables produces random values such as names e.g. `"{{$randomFirstName}}"`. More information can be found on the [Postman dynamic variables documentation](https://learning.postman.com/docs/writing-scripts/script-references/variables-list/).

These can be found throughout the collection, where general random values are helpful. For example, the *Tyk Demo > General Tests > Dashboard Admin API > Organisations > Get an Organisation* request uses `{{$randomCompanyName}}` to generate a random company name:

```javascript
var organisationName = pm.variables.replaceIn("{{$randomCompanyName}}");
tyk.dashboardAdminApi.organisations.create(
    JSON.stringify({ 
        owner_name: organisationName 
    }),
    (error, response) => {
        pm.expect(response.code).to.eql(200);
        pm.variables.set("organisation-id", response.json().Meta);
        pm.variables.set("organisation-name", organisationName);
    }, 
    pm
);
```
