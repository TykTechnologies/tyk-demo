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
