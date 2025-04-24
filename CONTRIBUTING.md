# Tyk Demo Contributor Guide

This guide provides comprehensive instructions for anyone who wants to contribute to or extend this repository. 

> **Tip:** You can use the Tyk deployment in `deployments/tyk` as a reference implementation.

## Table of Contents
- [Deployment Structure](#deployment-structure)
  - [Directory Name](#directory-name)
  - [Required Files](#required-files)
  - [Optional Files](#optional-files)
  - [Directory Structure](#directory-structure)
  - [Data Organisation](#data-organisation)
- [Creating a Deployment](#creating-a-deployment)
  - [Docker Compose Configuration](#docker-compose-configuration)
  - [Docker Environment Variables](#docker-environment-variables)
  - [Bootstrap Script](#bootstrap-script)
  - [Documentation](#documentation)
- [Working with Scripts](#working-with-scripts)
  - [Core Scripts](#core-scripts)
  - [Utility Scripts](#utility-scripts)
- [Managing API and Policy Data](#managing-api-and-policy-data)
  - [Exporting Changes](#exporting-changes)
  - [Synchronising Updates](#synchronising-updates)
- [Postman Testing Framework](#postman-testing-framework)
  - [Tyk Postman Library](#tyk-postman-library)
  - [Writing Tests](#writing-tests)
  - [Dynamic Testing Environment](#dynamic-testing-environment)
  - [Test Automation](#test-automation)
  - [Usage Examples](#usage-examples)
- [GitHub Test Workflow](#github-test-workflow)
  - [Overview](#overview)
  - [Workflow Structure](#workflow-structure)
  - [How It Works](#how-it-works)

## Deployment Structure

Deployments are discrete elements that enable users to choose what functionality to deploy. Each deployment should be contained within its own directory inside the `deployments` directory.

### Directory Name

The deployment directory name should reflect the purpose or functionality of the deployment:
- Use lowercase letters with words separated by hyphens (e.g., `my-deployment`)
- If the deployment is related to a particular theme, use the theme name as a prefix

For example, the `analytics-datadog` deployment relates to analytics reporting through Datadog. Prefixing the name in this way helps group related deployments together alphabetically.

### Deployment Files

**Required Files**

Every deployment must include these files:

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Defines the services to deploy |
| `bootstrap.sh` | Prepares the deployment for immediate use |
| `README.md` | Describes how to use the deployment |

**Optional Files**

| File | Purpose |
|------|---------|
| `tyk_demo_<DEPLOYMENT_NAME>.postman_collection.json` | Provides guided usage examples and validates functionality |
| `deployment.json` | Contains deployment metadata that can be read by scripts or external systems |
| `teardown.sh` | Run as part of `down.sh` process to remove resources not handled by Docker |

> **Note about Postman Collections:** While optional, collections are highly recommended as they provide guided usage examples and validate functionality. Example: `tyk_demo_mdcb.postman_collection.json` for the `mdcb` deployment.

### Directory Structure

Deployments may include these directories:

| Directory | Purpose |
|-----------|---------|
| `volumes` | Contains data used as Docker volumes |
| `data` | Contains data for bootstrapping |
| `scripts` | Contains deployment-specific scripts |

Both `volumes` and `data` directories should contain subdirectories named after the services defined in `docker-compose.yml`. For example, in the `tyk` deployment, the Gateway's configuration file is at `volumes/tyk-gateway/tyk.conf`.

### Data Organisation

Numbered directories within `/data/tyk-dashboard` allow data files to be processed in a structured manner.

```
data/
└── tyk-dashboard/
    ├── 1/
    │   ├── apis/
    │   └── policies/
    └── 2/
        ├── apis/
        └── policies/
```

This approach simplifies bootstrapping separate organisations and recording the resulting data. The bootstrap and export scripts process these directories in numerical order, enabling organised data handling.

## Creating a Deployment

### Docker Compose Configuration

Your deployment's `docker-compose.yml` must:

1. Define only the services specific to your deployment
2. Be compatible with the base deployment's `deployments/tyk/docker-compose.yml`

You don't need to redefine services already present in the base deployment (Dashboard, Gateway, etc.).

Example:

```yaml
version: '3.8'
services:
  my-custom-service:
    image: my-custom-image:latest
    ports:
      - "8888:8080"
    environment:
      - VARIABLE=value
    volumes:
      - ./deploymentys/my-deployment/volumes/my-custom-service:/etc/my-custom-service
```

### Docker Environment Variables

If your deployment requires specific Docker environment variables, use the `up.sh` script to verify and correct their values as needed.

The `scripts/common.sh` provides the `set_docker_environment_value` function to help manage these variables. 

Example:

```bash
# Example from up.sh for the instrumentation deployment
if [[ "$*" == *instrumentation* ]]; then
  set_docker_environment_value "INSTRUMENTATION_ENABLED" "1"
else
  set_docker_environment_value "INSTRUMENTATION_ENABLED" "0"
fi
```

### Bootstrap Script

The bootstrap script prepares your deployment for immediate demonstration. Follow these conventions for consistency:

#### Script Structure

```bash
#!/bin/bash

# Import common functions
source scripts/common.sh

# Set deployment name
deployment="My Deployment Name"

# Log deployment start
log_start_deployment

# Step 1: Setup Configuration
log_message "Setting up configuration"
# ... configuration code ...
log_message "  Additional details about configuration"
bootstrap_progress
log_ok

# Step 2: Creating Resources
log_message "Creating resources"
# ... resource creation code ...
bootstrap_progress
log_json_result "$response"

# Additional steps as needed...

# Log deployment completion
log_end_deployment

# Display deployment information
echo -e "\033[2K
▼ My Deployment Name
  ▽ Service Name
          Dashboard URL : http://localhost:3000
               Username : admin@example.com
               Password : $password_variable
  ▽ Another Service
           API Endpoint : http://localhost:8080/api"
```

#### Display Conventions

When displaying deployment information, follow this format:

- Start with `echo -e "\033[2K`
- Use `▼ Deployment Name` for the deployment name
- Use `▽ Service Name` for each service (indented 2 spaces)
- Format information as `Label : Value` with the colon at column 25
- Use `▾` and `▿` for nested information
- End with a closing quote (`"`)

#### Context Data

Store generated data in the `.context-data` directory to make it accessible to other scripts. The `scripts/common.sh` script provides `get_context_data` and `set_context_data` functions for this purpose.

```bash
# Setting context data
set_context_data "$data_group" "dashboard-user" "$index" "email" "$dashboard_user_email"
set_context_data "$data_group" "dashboard-user" "$index" "password" "$dashboard_user_password"

# Retrieving context data
username=$(get_context_data "1" "dashboard-user" "1" "email")
password=$(get_context_data "1" "dashboard-user" "1" "password")
```

### Documentation

Your deployment's `README.md` should include:

1. A clear description of the deployment's purpose
2. Example commands to deploy and use it
3. Any specific configuration or usage instructions
4. Any additional assets that are helpful, such as screenshots or diagrams

## Working with Scripts

### Core Scripts

The repository includes two main scripts:

- `up.sh`: Brings deployments up by:
  1. Setting environment variables correctly
  2. Running Docker Compose with the base Tyk deployment and any additional deployments
  3. Running bootstrap scripts for each deployment

- `down.sh`: Brings deployments down with the `-v` flag to remove volumes and prevent data persistence

The `up.sh` script accepts deployment names as arguments, with the base Tyk deployment included by default:

```bash
# Example: Deploy the base Tyk deployment plus the analytics deployment based on Kibana
./up.sh analytics-kibana
```

The `down.sh` script does not take arguments, instead reading from `.bootstrap/bootstrapped_deployments` to determine which deployments to stop.

### Utility Scripts

The `scripts` directory contains these utilities:

| Script | Purpose |
|--------|---------|
| `add-gateway.sh` | Creates a new Tyk Gateway container |
| `common.sh` | Provides common functions for bootstrap scripts |
| `export.sh` | Exports API and Policy definitions |
| `licences.sh` | Displays Tyk license information |
| `recreate-gateways.sh` | Recreates all current Tyk gateway containers |
| `test-all.sh` | Runs tests for all deployments |
| `test-common.sh` | Provides common functions for test scripts |
| `test.sh` | Runs Postman collection tests for bootstrapped deployments |
| `update-env.sh` | Adds or updates values in the `.env` file |
| `update-hosts.sh` | Updates `/etc/hosts` with necessary entries |

## Managing API and Policy Data

### Exporting Changes

If you've modified APIs or Policies, persist the data by exporting it:

```bash
./scripts/export.sh
```

This updates APIs and Policies within the `deployments/tyk/data/tyk-dashboard` path. For other data types, update the export script or export manually.

Update the relevant `bootstrap.sh` scripts to import the exported data.

When adding new functionality:
- Include Postman requests that demonstrate it
- Add tests to prevent regressions
- Verify tests pass by running `./scripts/test-all.sh`

Tests must be passing before a PR can be merged.

### Synchronising Updates

To get the latest changes from the remote repository:

```bash
./down.sh
git pull
./up.sh
```

This approach ensures that you cleanly import all the latest API definitions, policies, and other data.

Any updated Postman collections should be reimported into Postman.

## Postman Testing Framework

### Tyk Postman Library

The Tyk Postman Library provides functions for easy access to Tyk Gateway, Dashboard, and Admin APIs. It simplifies Tyk API access by wrapping Postman's `pm.sendRequest` method and automatically configuring the necessary request components.

The library is stored as a pre-request script in the root of the Postman collection, making it available to all requests.

Functions are organised by namespace:

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

### Writing Tests

Effective tests validate:

#### 1. HTTP Status Codes

```javascript
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});
```

#### 2. Response Body Data

```javascript
pm.test("Status is ok", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.status).to.eql("ok");
});
```

#### 3. Response Headers

```javascript
pm.test("'New-Header' header is present", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.headers['New-Header']).to.eql("new-header-value");
});
```

#### 4. Additional Request Validation

```javascript
pm.test("Rate limiting works", function () {
    var rateLimitRequest = {
        url: 'http://' + tykGatewayHost + '/basic-protected-api/get',
        method: 'GET',
        header: 'Authorization:' + keyId
    };
    
    // Make multiple requests to trigger rate limiting
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

Use Postman's dynamic variables for random test data:
```javascript
var organisationName = pm.variables.replaceIn("{{$randomCompanyName}}");
```

### Dynamic Testing Environment

For test scenarios requiring non-deterministic data (like randomly generated API keys), create a `dynamic-test-vars.env` file in your deployment directory:

```bash
echo "jwt=$portal_admin_api_token" > deployments/portal/dynamic-test-vars.env
```

The env file should contain key/value pairs, with one entry per line:
```
my-key=my-value
hello=world
```

### Test Automation

Deployments are included in test automation if they:
1. Include a Postman collection
2. Don't have a `test-runner-ignore` variable set to `true`
3. Contain tests in the collection

### Usage Examples

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

Notice that the Postman variables `user-id` and `user-api-key` are used to temporarily store the data so it can be used later in the request and tests.

#### Deleting Data

Always delete temporary data after it's no longer needed to prevent the Tyk deployment from accumulating test data:

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

The *Create an Organisation* request uses the `Meta` JSON value returned in the response to retrieve the organisation and validate its `owner_name` property:

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

The Dashboard API requires authentication using a Dashboard User API key. These keys are randomly generated when a user is created and can't be defined in advance.

To provide Dashboard API requests with a key, two functions generate and delete a key (and the related user):

1. Generate a key in the pre-request script (and set the `tyk-dashboard.api-key` environment variable):
   ```javascript
   tyk.dashboardApi.tools.apiKey.create(pm);
   ```

2. Use the key in requests via the Postman environment variable:
   ```
   Authorization: {{tyk-dashboard.api-key}}
   ```

3. Delete the key (and user) after tests are complete:
   ```javascript
   tyk.dashboardApi.tools.apiKey.delete(pm);
   ```

## GitHub Test Workflow

### Overview

The [Tyk Demo Tests workflow](.github/workflows/tyk-demo-tests.yml) is an automated testing framework that validates all deployment configurations in our repository. This workflow runs automatically on every push and ensures that each deployment configuration is properly tested and verified.

### Workflow Structure

The workflow consists of four main jobs:

1. **Discover Deployments**: Scans the repository to find all deployment configurations
2. **Test Deployments**: Runs tests against each deployment in parallel 
3. **Collect Results**: Gathers test results from all deployments
4. **Display Results**: Summarises the test results in a readable format

### How It Works

#### Discovery Phase

The workflow begins by scanning the `deployments/` directory to find all deployment configurations. It also extracts the Tyk Gateway Docker image tag to ensure consistent testing across all deployments.

#### Testing Phase

Each deployment undergoes the following test process:

- **Environment Setup**: Configures necessary environment variables and licences
- **Deployment Creation**: Spins up the deployment using the `up.sh` script
- **Test Validation**: Checks for the presence of two types of tests:
  - **Postman Tests**: API tests defined in Postman collections
  - **Custom Tests**: Custom test scripts specific to each deployment
- **Test Execution**: Runs both types of tests if available
- **Log Collection**: Captures container logs for debugging purposes

#### Results Collection

After all tests complete, the workflow:
- Collects individual test results
- Combines them into a single report
- Publishes the report as an artifact

#### Results Display

The final step displays a summary table showing the status of each deployment:

```
DEPLOYMENT            DEPLOY  POSTMAN CUSTOM  OVERALL
-------------------------------------------------------
deployment-name       ✅      ✅      ❌      ❌
```

#### Test Types

The workflow supports two types of tests:

1. **Postman Tests**: API tests using Postman collections located in the deployment directory
2. **Custom Tests**: Shell scripts or other custom test implementations specific to each deployment

> **Note:** Whether the deployment is successfully deployed is also counted as a test

#### Configuration Options

Each deployment can include a `deployment.json` file with the following options:

```json
{
  "github": {
    "skipDeployment": false
  },
  "composeArgument": "custom-arg",
  "dependencies": ["websocat"]
}
```

- `skipDeployment`: Set to `true` to exclude a deployment from github workflow testing
- `composeArgument`: Custom argument to pass to the `up.sh` script
- `dependencies`: Additional tools needed for testing (e.g., "websocat")
