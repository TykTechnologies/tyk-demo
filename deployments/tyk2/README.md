# Tyk environment 2

 This deployment represents a separate Tyk environment, with an independent Gateway, Dashboard, Pump and databases from the base `tyk` deployment. 

- [Tyk Dashboard environment 2](http://localhost:3002)
- [Tyk Gateway environment 2](http://localhost:8085/basic-open-api/get)

## Setup

Run the `up.sh` script with the `tyk2` parameter:

```
./up.sh tyk2
```

### Configuration

The configuration for the containers deployed here is mainly taken from the configuration from the standard `tyk` deployment, with the exception of the Tyk Pump.

Critical values, such as database connection strings are overridden with environment variables to ensure the Tyk components connect to the database contained within this deployment.

## Usage

This deployment is intended to be used in conjunction with the CI/CD feature, but it can be deployed separately if desired. When deployed with `cicd-jenkins`, Jenkins is used to automate the deployment of API Definitions and Policies from the default environment to this environment.