# Curity

## Overview

This deployment creates a Curity IdP instance and Tyk configuration to enable Dynamic Client Registration (DCR) with the Enterprise Portal.

DCR is a way for you to integrate the Developer Portal with an external identity provider, in this case Curity. The portal developer won't notice a difference, however, when they create an OAuth client in the Developer portal, Tyk will dynamically register that client on the Curity authorization server. This means that it is the Curity Authorization Server that will issue the Client ID and Client Secret for the app, not Tyk.

## Setup

Head over to `https://developer.curity.io/free-trial` to register for a free trial.  Pop your trial license under the `volumes/curity` directory with the filename `license.json`.

Run `dcr-curity` with the Enterprise Portal:
```
./up.sh portal dcr-curity
```

Visit `http://curity:6749/` to access the Curity admin console, and login with the credentials `admin/Password1`

Login to Tyk Dashboard and you should find the following resources have been created:

- **API**: `Curity DCR API`
- **API Product Policy**: `Curity DCR Product`
- **API Plan Policy**: `Curity DCR Plan`

In the Enterprise Portal Admin:
- **OAuth Provider**: `Curity DCR Provider` 
- **Client Type**: `Confidential Client` (linked to the product)
- **API Product**: `Curity DCR Product` (with DCR enabled)
- **Plan**: `Curity DCR Plan` (with DCR enabled)

## Usage

Login to the Enterprise Developer Portal at `http://tyk-portal.localhost:3100` then:
1. Register as a developer or login with existing credentials
2. Navigate to the "API Products" section
3. Subscribe to the "Curity DCR API Product"
4. Click on the OAuth Clients navigation bar button 
5. Follow the wizard to create an OAuth client - you just need to provide a `client name` as `Redirect URL` is not required for the OAuth2 `client_credentials` grant type

Next head over to Postman and using the Postman collection included in the Deployment, obtain an access token from Curity.

Once you have the access token, send a request to the `Curity DCR API`, providing the access token as an `Authorization` header.


## Postman Collection

You can import the deployment-specific Postman collection `tyk_demo_curity_dcr.postman_collection.json`.