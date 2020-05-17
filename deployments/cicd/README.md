# CI/CD

CI/CD is demonstrated using Jenkins and Tyk Sync. These provide an automated way of pushing API Definitions and Policies to different Tyk environments.

- [Jenkins Dashboard](http://localhost:8070)

## Setup

This feature depends on the Tyk Environment 2 deployment, so the two must be deployed together. The `tyk2` parameter should be provided before the `cicd` parameter, as the the CI/CD deployment requires some information from the Tyk Environment 2 deployment: 

```
./up.sh tyk2 cicd
```

The bootstrap process installs the necessary plugins, adds a job and imports environment credentials into Jenkins. This is everything you need to get started.

It can take a while for the bootstrap process to complete. This is due to the necessary Jenkins APIs being unavailable until Jenkins has fully started.

## Usage

After the bootstrap process is complete, the CI/CD functionality can be demonstrated.

When the bootstrap process creates the job in Jenkins, the job is run. It uses Tyk Sync to push the APIs and Policies into Tyk Environment 2. You can check to see whether these policies exist:

1. Log into the [Tyk environment 2 Dashboard](http://localhost:3002) (using credentials shown in bootstrap output, and a private browser session to avoid invalidating your session cookie for the default Dashboard)
2. You will see that there are no API Definitions or Policies
3. Check that the Tyk environment 2 Gateway can proxy requests for these APIs by making a request to the [Basic Open API](http://localhost:8085/basic-open-api/get)

**Note**: To avoid having to wait a long time for the Github anonymous API access quota to renew, it's recommended that you update the `APIs and Policies` job to use your Github credentials:

1. Go to `APIs and Policies` job
2. Click Configure
3. On Credentials field, click Add and select 'APIs and Policies'
4. Enter your username and password, then click Add
5. Select your credentials in the Credentials select box, then click Save
