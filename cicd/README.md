## Jenkins

Jenkins is used to provide an automated way of pushing API Definitions and Policies to different Tyk environments. It uses the `tyk-sync` CLI tool and a Github repository to achieve this.

- [Jenkins Dashboard](http://localhost:8070)

### Setup

For full CI/CD flow, you should deploy both this and the Tyk Environment 2 feature. Run from repo root:

```
docker-compose \
  -f docker-compose.yml \
  -f tyk-2/docker-compose.yml \
  -f cicd/docker-compose.yml up -d && \
./bootstrap.sh && \
tyk-2/bootstrap.sh && \
cicd/bootstrap.sh
```

The `cicd/bootstrap.sh` script installs plugins and adds a job to Jenkins, but you will need to follow these steps to complete the setup:

1. Browse to [Jenkins web UI](http://localhost:8070)
2. Add credentials: (these are needed by `tyk-sync` to push data into the Dashboard in environment 2)
  - Kind: Secret text
  - Scope: Global
  - Secret: The environment 2 Dashboard API credentials (these are displayed in the output of the `tyk-2/bootstrap.sh` script
  - ID: `tyk-dash-secret`
  - Description: `Tyk Dashboard Secret`

Ideally, this will be automated in the future.

### Usage

After the setup process is complete, the CI/CD functionality can be demonstrated as follows:

1. Log into the [Tyk environment 2 Dashboard](http://localhost:3002) (using credentials shown in bootstrap output, and a private browser session to avoid invalidating your session cookie for the default Dashboard)
2. You will see that there are no API Definitions or Policies
3. Build the `APIs and Polcies` job in Jenkins
4. Check the Tyk environment 2 Dashboard again, you will now see that it has the same API Definitions and Policies as the default Dashboard.
5. Check that the Tyk environment 2 Gateway can proxy requests for these APIs by making a request to the [Basic Open API](http://localhost:8085/basic-open-api)
