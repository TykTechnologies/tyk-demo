# Database PostgreSQL

This deployment uses a PostgreSQL database instead of MongoDB for storing the Tyk Dashboard configuration data. The base Tyk deployment still deploys the MongoDB and bootstraps the data into it, but this deployment then migrates that data into PostgreSQL and redeploys the Tyk Dashboard to use PostgreSQL instead.

The MongoDB database is kept running, as it's still used by the Tyk Pump and Dashboard to store and display analytics data.

When the `mongo_url` value in the Dashboard `tyk_analytics.conf` is set to a blank value, the Dashboard will use the configuration from the `storage` part of the configuration file instead. This contains the PostgreSQL connection string, which the Dashboard then uses to store its configuration data, such as API Definitions and Policies.

See the Tyk Documentation for [more information about using SQL with Tyk](https://tyk.io/docs/planning-for-production/database-settings/sql/#introduction). 

## Setup

Run the `up.sh` script with the `database-postgres` parameter:

```
./up.sh database-postgres
```

## Usage

The effect of using PostgreSQL is not visible to end users.

However, to confirm that PostgreSQL is being used to store the Tyk Dashboard configuration data, you can do the following:

1. Use a terminal to run this script. It uses the Dashboard API to import an API Definition, then queries the PostgreSQL database for it:
```
./deployments/database-postgres/check-sql-data.sh
```
2. If successful, the script should produce the following output, showing a single result:
```
Importing an API Definition called "Hello PostgreSQL" into the Dashboard
Querying PostgreSQL for an API called "Hello PostgreSQL" - expecting result to show 1 row
       name
------------------
 Hello PostgreSQL
(1 row)
```
