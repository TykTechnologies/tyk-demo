#!/bin/bash

source scripts/common.sh

echo "Querying PostgreSQL for an API called \"$1\""

$(generate_docker_compose_command) exec -u postgres tyk-postgres sh -c "psql -U postgres -d tyk_analytics -c \"SELECT name FROM tyk_apis WHERE name = '$1';\""
