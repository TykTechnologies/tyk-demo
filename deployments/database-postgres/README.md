# Database PostgreSQL

This deployment uses the PostgreSQL database instead of MongoDB. The base Tyk deployment still deploys the MongoDB and bootstraps the data into it, but this deployment then migrates that data into PostgreSQL and redeploys the Tyk Dashboard to use PostgreSQL instead.

## Setup

Run the `up.sh` script with the `database-postgres` parameter:

```
./up.sh database-postgres
```

## Usage

There's no particular 'usage' for this deployment, as end users do not interact directly with the database.