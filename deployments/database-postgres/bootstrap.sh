#!/bin/bash

source scripts/common.sh
deployment="Database PostgreSQL"
log_start_deployment

log_message "Creating Tyk Database in PostgreSQL tyk-postgres"

./docker-compose-command.sh exec -u postgres tyk-postgres sh -c \"psql -U postgres -c \'CREATE DATABASE tyk-analytics\'\"

log_end_deployment

echo -e "\033[2K
▼ Database
  ▽ PostgreSQL:
               Username : postgres
               Password : qtpNQY8UKPH3YrDk"