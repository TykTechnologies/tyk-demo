#!/bin/bash

source scripts/common.sh
deployment="Database PostgreSQL"
log_start_deployment

log_message "Creating Tyk Database (tyk_analytics) in PostgreSQL (tyk-postgres)"
eval $(generate_docker_compose_command) exec -T -u postgres tyk-postgres sh -c \"psql -U postgres -c \'CREATE DATABASE tyk_analytics\'\" 1>>bootstrap.log 2>&1
if [ "$?" != 0 ]; then
  echo "Error occurred when creating PostgreSQL database."
  exit 1
fi
log_ok
bootstrap_progress

# log_message "Migrating data from MongoDB to PostgreSQL"
# if [ "$?" != 0 ]; then
#   echo "Error occurred when migrating data."
#   exit 1
# fi
# log_ok
# bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Database
  ▽ PostgreSQL:
                Service : tyk-postgres
               Username : postgres
               Password : qtpNQY8UKPH3YrDk"