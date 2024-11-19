# Backstage Entity Provider

This deployment deploys backstage with the Tyk Entity Provider. It demonstrates how Tyk API definitions can be imported into a Backstage catalog.

The Backstage dashboard can be accessed here:
- [Backstage Dashboard](http://localhost:3003)

## Setup

### NPM Access Token
An access token is required to access the [Tyk entity provider NPM package](https://www.npmjs.com/package/@tyk-technologies/plugin-catalog-backend-module-tyk). The token value must be provided in the `.env` file as `BACKSTAGE_NPM_TOKEN`, for example:

```conf
BACKSTAGE_NPM_TOKEN=my-access-token
```

**Note**: The bootstrap process will fail if an NPM access token is not present - speak with your Tyk representitive to obtain a token. Using an incorrect token will result in an NPM error message `An unexpected error occurred: "https://registry.yarnpkg.com/@tyk-technologies%2fplugin-catalog-backend-module-tyk: Not found"`.

### Bootstrap

To use this deployment, run the `up.sh` script with the `portal-backstage` parameter:

```sh
./up.sh portal-backstage
```

**Note**: The first time the bootstrap is run, it will build the Backstage container image. This process can take a while (~5 minutes on a 2020 MacBook Pro), but it's a one-time process, as the resulting image is cached and reused for subsequent deployments.

## Configuration

### Backstage Configuration

The entity provider is configured via the mapped [app-config.yaml](deployments/portal-backstage/volumes/backstage/app-config.yaml) file:

```yaml
tyk:
  globalOptions:
    router:
      enabled: true
    scheduler:
      enabled: true
      frequency: 5
    importCategoriesAsTags: true
  dashboards:
    - host: http://tyk-dashboard:3000
      token: ${TYK_DASHBOARD_API_TOKEN}
      name: development
      defaults:
        owner: group:default/guests
        system: system:default/tyk
        lifecycle: development
```

This config is set up to synchronise with the Tyk dashboard deployed by the `tyk` deployment, using both the *router* and *scheduler* approaches. This means that synchronisation occurs dynamically, based on data changing in the Tyk dashboard, and also on a schedule, every 5 minutes. 

It's possible to import Tyk data from multiple dashboards by adding additional dashboard configurations to the `dashboards` section of the config. Ensure that each dashboard config has a unique `name` value.

### Catalog Configuration

There is a ['base' Tyk catalog file](deployments/portal-backstage/volumes/backstage/tyk-catalog.yaml) that's used to define entities that aren't generated through the entity provider. This includes the `tyk` system entity, which is connected to all Tyk entities.

## Usage

The [Backstage dashboard](http://localhost:3003) becomes accessible once the Tyk Demo bootstrap process is complete. It may take around 10 seconds for the site to compile, so there might be a short delay before it initially responds.

The Tyk entity provider is initialised during the Backstage startup, which includes an initial data synchronisation. As a result, Tyk-managed APIs are immediately available in the Backstage catalog.

The synchronisation process reads Tyk API definition data from the Tyk dashboard and converts it into Backstage API entities.

### Staticly Defined Entities

Some entities cannot be imported from the Tyk dashboard, such as the `system`, which is Backstage concept. To handle this, we include an entity yaml file that contains entities we want to include in the catalog. You can find these entities in the [`tyk-catalog.yaml` file](deployments/portal-backstage/volumes/backstage/tyk-catalog.yaml).

### Triggering the Synchronisation Process

You can trigger the synchronisation process in two ways:

#### 1. Change Tyk Dashboard API Definition Data

Any changes to API definitions in the Tyk dashboard—such as adding, editing, or deleting APIs—will automatically trigger synchronisation. The dashboard sends a webhook request to the entity provider sync endpoint, causing the changes to be reflected in the Backstage catalog almost immediately.

To view the results, check the Backstage log by running:

```sh
docker logs -f tyk-demo-backstage-1
```

The log will display messages similar to this, showing the entity provider synchronisation result and the request to the endpoint that triggered it:

```log
[1] 2024-09-13T15:35:31.789Z catalog info Importing 52 Tyk entities from development Dashboard entityProvider=tyk-entity-provider-development
[1] 2024-09-13T15:35:31.797Z rootHttpRouter info [13/Sep/2024:15:35:31 +0000] "GET /api/catalog/tyk/development/sync HTTP/1.1" 200 - "-" "curl/8.9.1" type=incomingRequest
```

The changes will also be reflected in the entities displayed in the Backstage catalog.

#### 2. Call the Entity Provider Sync Endpoint

Synchronisation can be manually triggered by calling the entity provider sync endpoint using the following `curl` command:

```sh
curl http://localhost:7007/api/catalog/tyk/development/sync
```
