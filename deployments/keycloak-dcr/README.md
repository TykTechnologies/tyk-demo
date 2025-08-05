# Keycloak

## Overview

This deployment creates a Keycloak IdP instance and Tyk configuration to enable Dynamic Client Registration (DCR) with the Enterprise Portal.

DCR is a way for you to integrate the Developer Portal with an external identity provider, in this case Keycloak. The portal developer won't notice a difference, however, when they create an OAuth client in the Developer portal, Tyk will dynamically register that client on the Keycloak authorization server. This means that it is the Keycloak Authorization Server that will issue the Client ID and Client Secret for the app, not Tyk.

## Setup

Run `keycloak-dcr` with the Enterprise Portal:
```
./up.sh portal keycloak-dcr
```

Visit `http://keycloak:8180/` to access the keycloak admin console, and login with the credentials `admin/admin`

Under the Client Registration tab you should find that an `initial access` token has been automagically created during the deployment bootstrap.

Login to Tyk Dashboard and you should find the following resources have been created:

- **API**: `Keycloak DCR API`
- **Policy**: `Keycloak DCR Policy`
- **Product**: `Keycloak DCR API Product` (with DCR enabled)
- **Plan**: `Keycloak DCR Access Plan`

In the Enterprise Portal Admin:
- **OAuth Provider**: `Keycloak DCR Provider` 
- **Client Type**: `Confidential Client` (linked to the product)

## Usage

Login to the Enterprise Developer Portal at `http://tyk-portal.localhost:3100` then:
1. Register as a developer or login with existing credentials
2. Navigate to the "API Products" section
3. Subscribe to the "Keycloak DCR API Product"
4. Click on the OAuth Clients navigation bar button 
5. Follow the wizard to create an OAuth client - you just need to provide a `client name` as `Redirect URL` is not required for the OAuth2 `client_credentials` grant type

Next head over to Postman and using the Postman collection included in the Deployment, obtain an access token from Keycloak.

Once you have the access token, send a request to the `Keycloak DCR API`, providing the access token as an `Authorization` header.


## Postman Collection

You can import the deployment-specific Postman collection `tyk_demo_keycloak_dcr.postman_collection.json`.