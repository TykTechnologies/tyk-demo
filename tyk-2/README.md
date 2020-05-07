## Tyk environment 2

This is intended to be used in conjunction with the CI/CD feature. It represents a separate Tyk environment, with an independent Gateway, Dashboard, Pump and databases. We can use Jenkins to automate the deployment of API Definitions and Policies from the default environment to this environment.

- [Tyk Dashboard environment 2](http://localhost:3002)
- [Tyk Gateway environment 2](http://localhost:8085/basic-open-api/get)

### Configuration

The configuration for the containers deployed here is mainly taken from the configuration from the standard Tyk deployment (`/tyk`), with the exception of the Tyk Pump.

Critical values, such as database connection strings are overridden with environment variables to ensure the Tyk components connect to the database contained within this deployment.