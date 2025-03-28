# Enterprise Developer Portal

This deployment spins up the Enterprise Developer Portal (formerly Raava).

The portal can be accessed here:
- [Developer Portal](http://localhost:3100)

## Setup

### License
Portal currently shares the license with the dashboard. Ensure that you have set your license key your .env file. Additionally, portal specific env vars will be exported to your .env file. 

The bootstrap process will fail if the licence is not present.

### Bootstrap

To use this deployment, run the `up.sh` script with the `portal` parameter:

```shell
./up.sh portal
```

This install comes bootstrapped with an admin user, an external api consumer user and an internal api developer user. 
The Portal will spin up a Postgres database containing portal configurations as well as assets. 
There is an exposed logfile in the directory `./deployments/portal/volumes/portal.log` for debugging purposes.

### Testing
In order to test the endpoints of this deployment, run the standard test script:

```shell
./scripts/test.sh
```

Make sure that the deployment is bootstrapped first.

The tests will run for both the standard `tyk` deployment and also the `portal` deployment.


## Usage

The Portal's theme is located in the [./volumes/theme](./volumes/theme/) directory, and is mounted directly into the Portal container. 

This means, you can make changes to the custom themes, add new pages and templates, and it changes can be reloaded on refreshes!

There are two examples included

### Embedded GraphQL Portal

The Catalogue has been modified to include a link to a GQL section, which includes an embedded GraphQL Portal available in the Catalogue.

This serves an example as to the kind of customizations we can make to the Dev Portal, using custom HTML, JS, and CSS.

The GQL Schema on the custom page [graphql-playground.tmpl](./volumes/theme/default/views/graphql-playground.tmpl) loads a GQL API hosted by Tyk API Gateway.


### Stripe Integration

Another example includes adding a Stripe Checkout flow, by modifying the [portal_checkout.tmpl].  After submitting an access request via the Cart, the user will be presented with a "Buy Now" button which generates a Stripe Checkout session.  After making a [fake payment](https://docs.stripe.com/testing), the user is redirected back to the Portal.

This serves as an example of one kind of Monetization flow.