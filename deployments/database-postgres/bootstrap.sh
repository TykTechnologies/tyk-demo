#!/bin/bash

source scripts/common.sh
deployment="Database PostgreSQL"
log_start_deployment

log_message "Creating Tyk Dashboard database (tyk_analytics) in PostgreSQL (tyk-postgres)"
eval $(generate_docker_compose_command) exec -T -u postgres tyk-postgres sh -c \"psql -U postgres -c \'CREATE DATABASE tyk_analytics\'\" 1>>bootstrap.log 2>&1
if [ "$?" != 0 ]; then
  echo "Error occurred when creating PostgreSQL database."
  exit 1
fi
log_ok
bootstrap_progress

log_message "Migrating data from MongoDB (tyk-mongo) to PostgreSQL (tyk-postgres)"
eval $(generate_docker_compose_command) exec -T tyk-dashboard sh -c \"/opt/tyk-dashboard/tyk-analytics migrate-sql\" 1>>bootstrap.log 2>&1
if [ "$?" != 0 ]; then
  echo "Error occurred when migrating data."
  exit 1
fi
log_ok
bootstrap_progress

# log_message "Stopping MongoDB (tyk-mongo)"
# eval $(generate_docker_compose_command) stop tyk-mongo 1>>bootstrap.log 2>&1
# if [ "$?" != 0 ]; then
#   echo "Error occurred when stopping Mongo service (tyk-mongo)."
#   exit 1
# fi
# log_ok
# bootstrap_progress

log_message "Removing Tyk Dashboard (tyk-dashboard)"
eval $(generate_docker_compose_command) rm -s -f tyk-dashboard 1>>bootstrap.log 2>&1
if [ "$?" != 0 ]; then
  echo "Error occurred when stopping Tyk Dashboard service (tyk-dashboard)."
  exit 1
fi
log_ok
bootstrap_progress

log_message "Recreating Dashboard to use new database configuration"
eval $(generate_docker_compose_command) run -T -d -e TYK_DB_MONGOURL='' --service-ports --use-aliases tyk-dashboard 1>>bootstrap.log 2>&1
if [ "$?" != 0 ]; then
  echo "Error occurred when recreating Dashboard to use new database configuration."
  exit 1
fi
log_ok
bootstrap_progress

# pump config?

# other services which reference mongoDB?

log_end_deployment

echo -e "\033[2K
▼ Database
  ▽ PostgreSQL:
                Service : tyk-postgres
               Database : tyk_analytics
               Username : postgres
               Password : qtpNQY8UKPH3YrDk"