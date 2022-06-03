# Database PostgreSQL

This deployment uses a PostgreSQL database instead of MongoDB for storing the Tyk Dashboard configuration data. The base Tyk deployment still deploys the MongoDB and bootstraps the data into it, but this deployment then migrates that data into PostgreSQL and redeploys the Tyk Dashboard to use PostgreSQL instead.

The MongoDB database is kept running, as it is still used by the Tyk Pump to store analytics data.

See the Tyk Documentation for [more information about using SQL with Tyk](https://tyk.io/docs/planning-for-production/database-settings/sql/#introduction). 

## Setup

Run the `up.sh` script with the `database-postgres` parameter:

```
./up.sh database-postgres
```

## Usage

The effect of using PostgreSQL is not visible to end users. However, if you want to confirm that PostgreSQL is being used to store the Tyk Dashboard configuration data, you can do the following:

1. Use the Dashboard to create a new API Definition called "SQL TEST" (use all caps)
2. Use a terminal to run this script. It checks the PostgreSQL database for the newly created API:
```
./deployments/database-postgres/check-sql-data.sh "SQL TEST"
```
3. If successful, the script should produce the following output, showing a single result:
```
Querying PostgreSQL for an API called "SQL TEST"
   name
----------
 SQL TEST
(1 row)
```
