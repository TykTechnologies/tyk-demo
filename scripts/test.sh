#!/bin/bash

# runs the postman collection tests for deployments that a currently deployed

# Stop on first error
set -e;

function onExit {
    if [ "$?" != "0" ]; then
        echo "Tests failed";
        exit 1;
    else
        echo "Tests passed";
    fi
}

trap onExit EXIT;

# loop through bootstrapped deployments
while IFS= read -r deployment; do
    echo "Running tests for $deployment deployment"

    # Provide the 'test' environment variables, so newman can target the correct hosts from within the docker network
    # --insecure option is used due to self-signed certificates
    docker run -t --rm \
        --network tyk-demo_tyk \
        -v $(pwd)/deployments/$deployment/tyk_demo_$deployment.postman_collection.json:/etc/postman/tyk_demo.postman_collection.json \
        -v $(pwd)/test.postman_environment.json:/etc/postman/test.postman_environment.json \
        postman/newman:alpine \
        run "/etc/postman/tyk_demo.postman_collection.json" \
        --environment /etc/postman/test.postman_environment.json \
        --insecure
done < .bootstrap/bootstrapped_deployments
