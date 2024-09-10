# Backstage Entity Provider

This deployment deploys backstage with the Tyk Entity Provider. It demonstrates how Tyk API definitions can be imported into a Backstage catalog.

The Backstage dashboard can be accessed here:
- [Backstage Dashboard](http://localhost:3003)

## Setup

### NPM Access Token
An access token is required to access the [Tyk entity provider NPM package](https://www.npmjs.com/package/@tyk-technologies/plugin-catalog-backend-module-tyk). The token value must be provided in the `.env` file as `BACKSTAGE_NPM_TOKEN`, for example:

```
BACKSTAGE_NPM_TOKEN=my-access-token
```

**NOTE**: This token get embedded into the built Backstage image - do not distribute the image.

The bootstrap process will fail if an NPM access token is not present - speak with your Tyk representitive to obtain a token.

### Bootstrap

To use this deployment, run the `up.sh` script with the `portal-backstage` parameter:

```
./up.sh portal-backstage
```

The first time the bootstrap is run, it will build the Backstage container image. This process can take several minutes, but the resulting image will be cached and reused for future deployments.

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

This config is set up to synchronise with the Tyk dashboard deployed by the `tyk` deployment, using both the *router* and *scheduler* approaches. This means that synchronisation occurs dynamically, based on data changing in the Tyk dashboard, and also on a schedule, based on a particular number of minutes elapsing. 

Synchronisation takes place when the entity provider plugin is initialised, so you will find that Tyk-managed APIs are immediately available in Backstage.

### Catalog Configuration

There is a ['base' Tyk catalog file](deployments/portal-backstage/volumes/backstage/tyk-catalog.yaml) that's used to provide some entities that cannot be imported from Tyk itself. These include the `tyk` system entity, to which all other imported entities are connected.