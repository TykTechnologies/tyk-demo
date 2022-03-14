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

```
./up.sh portal
```
