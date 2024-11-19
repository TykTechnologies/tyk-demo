#!/bin/bash

# Runs the postman collection tests for deployments that are currently deployed
# Note: To test all deployments without having to bootstrap them first, use the test-all.sh script

if [ ! -s ".bootstrap/bootstrapped_deployments" ]; then
  echo "ERROR: No bootstrapped deployments found"
  echo "To run tests, first bootstrap a deployment, then run this script"
  exit 1
fi

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
    collection_path="$(pwd)/deployments/$deployment/tyk_demo_${deployment//-/_}.postman_collection.json"
    if [ ! -f $collection_path ]; then
        echo "$deployment deployment does not contain a postman collection"
        continue
    fi

    echo "Running tests for $deployment deployment"

    # Set up the test command
    # --environment provides the 'test' environment variables, so newman can target the correct hosts from within the docker network
    # --insecure option is used due to self-signed certificates
    test_cmd=(
        docker run -t --rm
        --network tyk-demo_tyk
        -v "$collection_path:/etc/postman/tyk_demo.postman_collection.json"
        -v "$(pwd)/test.postman_environment.json:/etc/postman/test.postman_environment.json"
        postman/newman:alpine
        run "/etc/postman/tyk_demo.postman_collection.json"
        --environment /etc/postman/test.postman_environment.json
        --insecure
    )

    # add dynamic env vars to the test command, if any exist
    dynamic_env_var_path="$(pwd)/deployments/$deployment/dynamic-test-vars.env"
    if [ -s "$dynamic_env_var_path" ]; then
        while IFS= read -r var; do
            test_cmd+=(--env-var "$var")
            echo "  Using dynamic env var: $var"
        done < "$dynamic_env_var_path"
    else 
        echo "  No dynamic environment variables found for $deployment deployment"
    fi

    # run the tests
    "${test_cmd[@]}"
done < .bootstrap/bootstrapped_deployments
